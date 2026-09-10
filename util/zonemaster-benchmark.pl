#!/usr/bin/env perl
use strict;
use warnings;
use Getopt::Long;
use Time::Piece;
use Zonemaster::Engine;
use Sys::Hostname;
use List::Util qw(uniq pairmap min max);
use Time::HiRes qw(gettimeofday tv_interval);
use File::Slurp;
use JSON::PP;
use Statistics::Descriptive;
use Text::SimpleTable::AutoWidth;

# Usage:
#   zonemaster-benchmark zonemaster.fr
#   zonemaster-benchmark --batch domains.txt
#   zonemaster-benchmark zonemaster.fr --cache
#   zonemaster-benchmark zonemaster.fr --cache --cache_dir caches/
#   zonemaster-benchmark zonemaster.fr --cache --runs 3
#   zonemaster-benchmark --batch domains.txt --cache --runs 10 --output data.json
#
#   if you want to get caches before running benchmark:
#   zonemaster-benchmark zonemaster.fr --cache --runs 0
#
# domain and --batch can't be used at the same time.

my $opt_batch_file;
my $opt_use_cache = 0;
my $opt_cache_dir = "/tmp/";  # DEFAULT CACHE DIRECTORY
my $opt_profile;
my $opt_nbruns = 1;
my $opt_output;

GetOptions(
    'batch=s' => \$opt_batch_file,
    'cache'   => \$opt_use_cache,
    'cache_dir=s' => \$opt_cache_dir,
    'profile=s' => \$opt_profile,
    'runs=i' => \$opt_nbruns,
    'output=s' => \$opt_output
) or die "Usage: $0 (domain | --batch FILE) [--profile PROFILE] [--cache] [--cache_dir DIR] [--runs NB] [--output FILE]\n";

my $domain_arg = $ARGV[0];

# Check mutual exclusivity between domain and --batch
if (defined $opt_batch_file && defined $domain_arg) {
    die "Error: use either a single domain OR --batch FILE, not both.\n";
}

if (!defined $opt_batch_file && !defined $domain_arg) {
    die "Error: you must specify either a domain or --batch FILE.\n";
}

# Collect domains
my @domains;

# if there is a batch argument
# push all domain name inside @domains
if (defined $opt_batch_file) {
    open my $bfh, '<', $opt_batch_file
      or die "Cannot open batch file '$opt_batch_file': $!\n";
    while (my $line = <$bfh>) {
        #chomp $line;
        $line =~ s/[\r\n]//g; #remove \r and \n
        next if $line =~ /^\s*$/;
        push @domains, $line;
    }
    close $bfh;
} else {
    # otherwise push the only one in argument
    push @domains, $domain_arg;
}

# Validate opt_cache_dir if cache is enabled
if ($opt_use_cache) {
    unless (-d $opt_cache_dir && -w $opt_cache_dir) {
        die "Cache directory '$opt_cache_dir' must exist and be writable\n";
    }
}

# Validate opt_profile file
if (defined $opt_profile) {
    unless (-e $opt_profile && -r $opt_profile){
        die "Profile file '$opt_profile' must exist and be readable\n";
    }
    
}

my @collected_datas;
my $domain_count=0;

for my $d (@domains) {

    $domain_count++;

    
    my $cache_file = "$opt_cache_dir/$d.cache";
    if ( $opt_use_cache ) {
        unless (-e $cache_file && -r $cache_file && -s $cache_file) {
            #if cache file doesnt exist, create it
            print("$cache_file file does not exist, creating it...\n");
            Zonemaster::Engine->reset();
            Zonemaster::Engine->test_zone($d);
            Zonemaster::Engine->save_cache($cache_file);
        }
    }

    
    for my $run (1..$opt_nbruns){
        Zonemaster::Engine->reset();

        # Loading cache 
        if( $opt_use_cache ){
            #print("load cache file $cache_file\n");
            Zonemaster::Engine->preload_cache($cache_file);
        }
    
        # Loading opt_profile
        if (defined $opt_profile) {
            print("load profile ");
            my $json    = read_file( $opt_profile );
            my $loaded_profile     = Zonemaster::Engine::Profile->from_json( $json );
            my $default_profile = Zonemaster::Engine::Profile->default;
            $default_profile->merge( $loaded_profile );
            Zonemaster::Engine::Profile->effective->merge( $default_profile ); 
        }
    
        #print(encode_json(Zonemaster::Engine::Profile->effective->get("test_cases")), "\n");
        #printf("%i/%i: ",$domain_count,scalar(@domains)); 
        #print("benchmarking $d (run $run/$opt_nbruns) : "); 
        print(" $run / $opt_nbruns : $d "); 
        STDOUT->flush();     
        
        my $start = [gettimeofday];
        my @results = Zonemaster::Engine->test_zone($d);
        my $elapsed = tv_interval($start);

        printf("(%f) \r",$elapsed);
    
    
        my %times = timing(@results);
        $times{'domain'} = $d;
        $times{'time'} = $elapsed,
        $times{'hostname'} = hostname(),
        $times{'date'} = localtime->strftime('%m/%d/%Y %H:%M'),
        $times{'VersionEngine'} = Zonemaster::Engine->VERSION;

        push @collected_datas, {%times}

    }
    print("\n");
}

### OUTPUT

# if --output argument is used
# write all collected_datas to a file
if ($opt_output){
	open my $fh, ">", $opt_output;
	print $fh encode_json(\@collected_datas);
	close $fh;
    exit;
} 
	
# otherwise print summary on terminal

my %summary;

for my $i (@collected_datas){
    for my $key (keys %$i){
        push @{$summary{$key}}, $i->{$key};
    }
}


# cleanup summary by removing : date, VersionEngine, hostname, domain
delete $summary{date};
delete $summary{VersionEngine};
delete $summary{hostname};
delete $summary{domain};

my $st = Text::SimpleTable::AutoWidth->new();


$st->captions( [qw(Test Nb Min Max Mean Median)] );

foreach my $key (sort keys %summary) {
    my $values = $summary{$key};
   
    my $stat = Statistics::Descriptive::Full->new();
    $stat->add_data(@$values);

    $st->row( $key,scalar(@$values),$stat->min(),$stat->max(),$stat->mean(),$stat->median() );

}

print $st->draw;

#=============================================================================

# return the list of module present in a zonemaster results
sub list_modules {
        my (@entries) = @_;
        return uniq sort map { $_->module } @entries;
}

# return the list of testcases present inside results
# delete Unspecified
sub list_testcases{
        my (@entries) = @_;
        my @results = uniq sort map { $_->testcase } @entries;
        @results = grep { $_ ne "Unspecified" } @results;       # HACK
        return @results
}

sub time_testcase {
        my ($entries, $filter_testcase) = @_;
        my @entries = @$entries;

        my @filtered = grep { $_->testcase eq $filter_testcase } @entries;

        my ($start) = grep { $_->tag eq "TEST_CASE_START" } @filtered;
        my ($end) = grep { $_->tag eq "TEST_CASE_END" } @filtered;

        return $end->timestamp - $start->timestamp;
}

# take zonemaster's log and return an hash table 
# with test_case as key and times as value
sub timing {
    my (@entries) = @_;
    my @list_testcase = list_testcases(@entries);
    my %times; 
    foreach my $testcase (@list_testcase) {
        $times{$testcase} = time_testcase(\@entries, $testcase);
    }
    return %times;
}

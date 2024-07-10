package Zonemaster::Engine::TestMethodsV2;

use v5.16.0;
use warnings;

use version; our $VERSION = version->declare("v1.0.0");

use Carp;
use List::MoreUtils qw[uniq];

use Zonemaster::Engine::Util;

=head1 NAME

Zonemaster::Engine::TestMethodsV2 - Version 2 of Methods common to Test Specifications used in Test modules

=head1 SYNOPSIS

    my @results = Zonemaster::Engine::TestMethodsV2->get_parent_ns_ips($zone);

=head1 METHODS

For details on what these Methods implement, see the Test Specifications document
(https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/tests/MethodsV2.md).

=over

=item get_parent_ns_ips($zone)

[External]

This Method will obtain the name servers that serves the parent zone, i.e. the zone from which the Child Zone is delegated from.

Takes a L<Zonemaster::Engine::Zone> object.

Returns an arrayref of L<Zonemaster::Engine::Nameserver> objects, or C<undef> if no parent zone was found.

=back

=cut

sub get_parent_ns_ips {
    my ( $class, $zone ) = @_;

    my $is_undelegated = Zonemaster::Engine::Recursor->has_fake_addresses( $zone->name->string );

    if ( $zone->name->string eq "." or $is_undelegated ) {
        return [];
    }

    my %handled_servers;
    my @parent_found;

    my %rrs_ns;
    my $type_soa = q{SOA};
    my $type_ns = q{NS};

    my %all_servers = ( '.' => [ Zonemaster::Engine::Recursor->root_servers ] );
    my @all_labels = ( '.' );
    my @remaining_labels = ( '.' );

    ALL_SERVERS:
    while ( my $zone_name = shift @remaining_labels ) {
        my @remaining_servers = @{ $all_servers{$zone_name} };

        CUR_SERVERS:
        while ( my $ns = shift @remaining_servers ) {
            next CUR_SERVERS if grep { $_ eq $ns->address->short } @{ $handled_servers{$zone_name} };
            push @{ $handled_servers{$zone_name} }, $ns->address->short;

            if ( ( $ns->address->version == 4 and not Zonemaster::Engine::Profile->effective->get( q{net.ipv4} ) )
                or ( $ns->address->version == 6 and not Zonemaster::Engine::Profile->effective->get( q{net.ipv6} ) ) ) {
                next CUR_SERVERS;
            }

            my $p_soa = $ns->query( $zone_name, $type_soa );

            unless ( $p_soa and $p_soa->rcode eq 'NOERROR' and $p_soa->aa and scalar $p_soa->get_records_for_name( $type_soa, $zone_name, 'answer' ) == 1 ) {
                next CUR_SERVERS;
            }

            my $p_ns = $ns->query( $zone_name, $type_ns );

            unless ( $p_ns and $p_ns->rcode eq 'NOERROR' and $p_ns->aa and scalar $p_ns->get_records( $type_ns, 'answer' ) > 0
                and scalar $p_ns->get_records( $type_ns, 'answer' ) == scalar $p_ns->get_records_for_name( $type_ns, $zone_name, 'answer' )
            ) {
                next CUR_SERVERS;
            }

            $rrs_ns{name( $_->nsdname )->string} = [] for $p_ns->get_records_for_name( $type_ns, $zone_name, 'answer' );

            foreach my $rr ( $p_ns->get_records( 'A', 'additional' ), $p_ns->get_records( 'AAAA', 'additional' ) ) {
                if ( exists $rrs_ns{name( $rr->owner )->string} ) {
                    push @{ $rrs_ns{name( $rr->owner )->string} }, $rr->address;
                }
            }

            foreach my $ns_name ( keys %rrs_ns ) {
                unless ( scalar @{ $rrs_ns{$ns_name} } > 0 ) {
                    my $p_a = Zonemaster::Engine::Recursor->recurse( $ns_name, q{A} );

                    if ( $p_a and $p_a->rcode eq 'NOERROR' ) {
                        push @{ $rrs_ns{$ns_name} }, $_->address for $p_a->get_records_for_name( 'A', $ns_name );
                    }

                    my $p_aaaa = Zonemaster::Engine::Recursor->recurse( $ns_name, q{AAAA} );

                    if ( $p_aaaa and $p_aaaa->rcode eq 'NOERROR' ) {
                        push @{ $rrs_ns{$ns_name} }, $_->address for $p_aaaa->get_records_for_name( 'AAAA', $ns_name );
                    }
                }

                foreach my $ns_ip ( @{ $rrs_ns{$ns_name} } ) {
                    unless ( grep { $_ eq $ns_ip } @{ $handled_servers{$zone_name} } ) {
                        push @{ $all_servers{$zone_name} }, ns( $ns_name, $ns_ip );

                        unless ( grep { $_ eq $zone_name } @all_labels ) {
                            push @remaining_labels, $zone_name;
                            push @all_labels, $zone_name;
                        }
                    }
                }
            }

            my $intermediate_query_name = name( $zone_name );
            my $loop_zone_name = $zone_name;
            my $loop_counter = 0;

            LOOP:
            while() {
                $loop_counter += 1;
                if ( $loop_counter >= 1000 ) {
                    Zonemaster::Engine->logger->add( LOOP_PROTECTION => {
                        caller => 'Zonemaster::Engine::TestMethodsV2->get_parent_ns_ips',
                        child_zone_name => $zone->name,
                        name => $loop_zone_name,
                        intermediate_query_name => $intermediate_query_name
                      }
                    );

                    return undef;
                }

                last if scalar @{ $intermediate_query_name->labels } >= scalar @{ $zone->name->labels };
                $intermediate_query_name = name( @{ $zone->name->labels }[ ( scalar @{ $zone->name->labels } - scalar @{ $intermediate_query_name->labels } ) - 1 ] . '.' . $intermediate_query_name->string );

                $p_soa = $ns->query( $intermediate_query_name, $type_soa );

                unless ( $p_soa ) {
                    next CUR_SERVERS;
                }

                if ( $p_soa->rcode eq 'NOERROR' and $p_soa->aa and scalar $p_soa->get_records_for_name( $type_soa, $intermediate_query_name, 'answer' ) == 1 ) {
                    if ( $intermediate_query_name->string eq $zone->name->string ) {
                        push @parent_found, $ns;
                    }
                    else {
                        $p_ns = $ns->query( $intermediate_query_name, $type_ns );

                        unless ( $p_ns and $p_ns->rcode eq 'NOERROR' and $p_ns->aa and scalar $p_ns->get_records( $type_ns, 'answer' ) > 0
                            and scalar $p_ns->get_records( $type_ns, 'answer' ) == scalar $p_ns->get_records_for_name( $type_ns, $intermediate_query_name, 'answer' )
                        ) {
                            next CUR_SERVERS;
                        }

                        my %rrs_ns_bis;
                        $rrs_ns_bis{name( $_->nsdname )->string} = [] for $p_ns->get_records_for_name( $type_ns, $intermediate_query_name, 'answer' );

                        foreach my $rr ( $p_ns->get_records( 'A', 'additional' ), $p_ns->get_records( 'AAAA', 'additional' ) ) {
                            if ( exists $rrs_ns_bis{name( $rr->owner )->string} ) {
                                push @{ $rrs_ns_bis{name( $rr->owner )->string} }, $rr->address;
                            }
                        }

                        foreach my $ns_name ( keys %rrs_ns_bis ) {
                            unless ( scalar @{ $rrs_ns_bis{$ns_name} } > 0 ) {
                                my $p_a = Zonemaster::Engine::Recursor->recurse( $ns_name, q{A} );

                                if ( $p_a and $p_a->rcode eq 'NOERROR' ) {
                                    push @{ $rrs_ns_bis{$ns_name} }, $_->address for $p_a->get_records_for_name( 'A', $ns_name );
                                }

                                my $p_aaaa = Zonemaster::Engine::Recursor->recurse( $ns_name, q{AAAA} );

                                if ( $p_aaaa and $p_aaaa->rcode eq 'NOERROR' ) {
                                    push @{ $rrs_ns_bis{$ns_name} }, $_->address for $p_aaaa->get_records_for_name( 'AAAA', $ns_name );
                                }
                            }

                            foreach my $ns_ip ( @{ $rrs_ns_bis{$ns_name} } ) {
                                unless ( grep { $_ eq $ns_ip } @{ $handled_servers{$intermediate_query_name} } ) {
                                    push @{ $all_servers{$intermediate_query_name} }, ns( $ns_name, $ns_ip );

                                    unless ( grep { $_ eq $intermediate_query_name } @all_labels ) {
                                        push @remaining_labels, $intermediate_query_name;
                                        push @all_labels, $intermediate_query_name;
                                    }
                                }
                            }
                        }

                        $loop_zone_name = $intermediate_query_name->string;
                        next LOOP;
                    }
                }
                elsif ( $p_soa->is_redirect and scalar $p_soa->get_records_for_name( $type_ns, $intermediate_query_name, 'authority' ) ) {
                    if ( $intermediate_query_name->string eq $zone->name->string ) {
                        push @parent_found, $ns;
                    }
                    else {
                        my %rrs_ns_bis;
                        $rrs_ns_bis{name( $_->nsdname )->string} = [] for $p_soa->get_records_for_name( $type_ns, $intermediate_query_name, 'authority' );

                        foreach my $rr ( $p_soa->get_records( 'A', 'additional' ), $p_soa->get_records( 'AAAA', 'additional' ) ) {
                            if ( exists $rrs_ns_bis{name( $rr->owner )->string} ) {
                                push @{ $rrs_ns_bis{name( $rr->owner )->string} }, $rr->address;
                            }
                        }

                        foreach my $ns_name ( keys %rrs_ns_bis ) {
                            unless ( scalar @{ $rrs_ns_bis{$ns_name} } > 0 ) {
                                my $p_a = Zonemaster::Engine::Recursor->recurse( $ns_name, q{A} );

                                if ( $p_a and $p_a->rcode eq 'NOERROR' ) {
                                    push @{ $rrs_ns_bis{$ns_name} }, $_->address for $p_a->get_records_for_name( 'A', $ns_name );
                                }

                                my $p_aaaa = Zonemaster::Engine::Recursor->recurse( $ns_name, q{AAAA} );

                                if ( $p_aaaa and $p_aaaa->rcode eq 'NOERROR' ) {
                                    push @{ $rrs_ns_bis{$ns_name} }, $_->address for $p_aaaa->get_records_for_name( 'AAAA', $ns_name );
                                }
                            }

                            foreach my $ns_ip ( @{ $rrs_ns_bis{$ns_name} } ) {
                                unless ( grep { $_ eq $ns_ip } @{ $handled_servers{$intermediate_query_name} } ) {
                                    push @{ $all_servers{$intermediate_query_name} }, ns( $ns_name, $ns_ip );

                                    unless ( grep { $_ eq $intermediate_query_name } @all_labels ) {
                                        push @remaining_labels, $intermediate_query_name;
                                        push @all_labels, $intermediate_query_name;
                                    }
                                }
                            }
                        }
                    }
                }
                elsif ( $p_soa->rcode eq 'NOERROR' and $p_soa->aa ) {
                    next LOOP if $intermediate_query_name->string ne $zone->name->string;
                }

                next CUR_SERVERS;
            }
        }
    }

    if ( scalar @parent_found ) {
        return [ uniq sort @parent_found ]
    }
    else {
        return undef;
    }
}

=over

=item _get_oob_ips($zone, $ns_names_ref)

[Internal]

This Method will obtain the IP addresses of the Out-Of-Bailiwick name servers for the given zone and a given set of name server names.

Takes a L<Zonemaster::Engine::Zone> object and an arrayref of L<Zonemaster::Engine::Nameserver> objects.

Returns an arrayref of L<Zonemaster::Engine::Nameserver> objects for each name server name that was successfully resolved to an IP address,
and L<Zonemaster::Engine::DNSName> objects for each name server name that could not be resolved to an IP address.

=back

=cut

sub _get_oob_ips {
    my ( $class, $zone, $ns_names_ref ) = @_;

    if ( not defined $ns_names_ref or not scalar @{ $ns_names_ref } ) {
        return [];
    }

    my $is_undelegated = Zonemaster::Engine::Recursor->has_fake_addresses( $zone->name->string );
    my @oob_ns;
    my $found_ip;

    for my $ns_name ( @{ $ns_names_ref } ) {
        $found_ip = 0;

        if ( not $zone->name->is_in_bailiwick( $ns_name ) ) {
            if ( $is_undelegated and scalar Zonemaster::Engine::Recursor->get_fake_addresses( $zone->name->string, $ns_name->string ) ) {
                for my $ip ( Zonemaster::Engine::Recursor->get_fake_addresses( $zone->name->string, $ns_name->string ) ) {
                    $found_ip = 1;
                    push @oob_ns, ns( $ns_name->string, $ip );
                }
            }
            else {
                my $p_a = Zonemaster::Engine::Recursor->recurse( $ns_name->string, q{A} );

                if ( $p_a ) {
                    for my $rr ( $p_a->get_records_for_name( q{A}, $ns_name->string ) ) {
                        $found_ip = 1;
                        push @oob_ns, ns( $ns_name->string, $rr->address );
                    }
                }

                my $p_aaaa = Zonemaster::Engine::Recursor->recurse( $ns_name->string, q{AAAA} );

                if ( $p_aaaa ) {
                    for my $rr ( $p_aaaa->get_records_for_name( q{AAAA}, $ns_name->string ) ) {
                        $found_ip = 1;
                        push @oob_ns, ns( $ns_name->string, $rr->address );
                    }
                }
            }

            if ( not $found_ip ) {
                push @oob_ns, $ns_name;
            }
        }
    }

    return [ @oob_ns ];
}

=over

=item _get_delegation($zone)

[Internal]

This Method will obtain the name server names (from the NS records) and the IP addresses (from Glue records) from the delegation of the given zone from the parent zone.
Glue Records are address records for In-Bailiwick name server names, if any.

Takes a L<Zonemaster::Engine::Zone> object.

Returns an arrayref of L<Zonemaster::Engine::Nameserver> objects, or C<undef> if no parent zone was found.

=back

=cut

sub _get_delegation {
    my ( $class, $zone ) = @_;

    my $is_undelegated = Zonemaster::Engine::Recursor->has_fake_addresses( $zone->name->string );
    my %delegation_ns;
    my %aa_ns;
    my @ib_ns;
    my @names;

    if ( $is_undelegated ) {
        for my $ns_name ( Zonemaster::Engine::Recursor->get_fake_names( $zone->name->string ) ) {
            if ( $zone->name->is_in_bailiwick( name( $ns_name ) ) ) {
                for my $ns_ip ( Zonemaster::Engine::Recursor->get_fake_addresses( $zone->name->string, $ns_name ) ){
                    push @ib_ns, ns( $ns_name, $ns_ip);
                }
            }
            else {
                # Problem: Can't create an Engine::Nameserver object without an IP address... So we have to mix Engine::Nameserver and Engine::DNSName objects in the same array.
                push @ib_ns, name( $ns_name );
            }
        }

        return [ @ib_ns ];
    }
    elsif ( $zone->name->string eq '.' ) {
        return [ Zonemaster::Engine::Recursor->root_servers() ];
    }
    else {
        my $parent_ref = $class->get_parent_ns_ips( $zone );

        return undef if not defined $parent_ref;

        for my $ns ( @{ $parent_ref } ) {
            my $p = $ns->query( $zone->name, q{NS} );
            @names = ();

            if ( $p and $p->rcode eq q{NOERROR} ) {
                if ( $p->is_redirect ){
                    for my $rr ( $p->get_records_for_name( q{NS}, $zone->name->string, q{authority} ) ) {
                        $delegation_ns{$rr->nsdname} = [] if not exists $delegation_ns{$rr->nsdname};
                        push @names, $rr->nsdname;
                    }

                    for my $rr ( $p->get_records( q{A}, q{additional} ), $p->get_records( q{AAAA}, q{additional} ) ) {
                        if ( $zone->name->is_in_bailiwick( name( $rr->owner ) ) and scalar grep { $_ eq $rr->owner } uniq @names and exists $delegation_ns{$rr->owner} ) {
                            push @{ $delegation_ns{$rr->owner} }, $rr->address;
                        }
                    }
                }
                elsif ( $p->aa and scalar $p->get_records_for_name( q{NS}, $zone->name->string, q{answer} ) ) {
                    for my $rr ( $p->get_records_for_name( q{NS}, $zone->name->string, q{answer} ) ) {
                        $aa_ns{$rr->nsdname} = [] if not exists $aa_ns{$rr->nsdname};
                        push @names, $rr->nsdname;
                    }

                    for my $rr ( $p->get_records( q{A}, q{additional} ), $p->get_records( q{AAAA}, q{additional} ) ) {
                        if ( $zone->name->is_in_bailiwick( name( $rr->owner ) ) and scalar grep { $_ eq $rr->owner } uniq @names and exists $delegation_ns{$rr->owner} ) {
                            push @{ $aa_ns{$rr->owner} }, $rr->address;
                        }
                    }

                    for my $ns_key ( keys %aa_ns ) {
                        if ( not scalar $aa_ns{$ns_key} ) {
                            my ( $p_a, $state_a ) = Zonemaster::Engine::Recursor->_recurse( $ns_key, q{A}, q{IN}, { ns => [ $ns ], count => 0, common => 0, seen => {}, glue => {} } );
                            my ( $p_aaaa, $state_aaaa ) = Zonemaster::Engine::Recursor->_recurse( $ns_key, q{AAAA}, q{IN}, { ns => [ $ns ], count => 0, common => 0, seen => {}, glue => {} } );

                            if ( $p_a and $p_aaaa ) {
                                for my $rr ( $p_a->get_records_for_name( q{A}, $ns_key ), $p_aaaa->get_records_for_name( q{AAAA}, $ns_key ) ) {
                                    push @{$aa_ns{$ns_key}}, $rr->address;
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    if ( scalar keys %delegation_ns ) {
        for my $ns_key ( keys %delegation_ns ) {
            if ( scalar @{ $delegation_ns{$ns_key} } ) {
                for my $ns_ip ( uniq @{$delegation_ns{$ns_key}} ) {
                    push @ib_ns, ns( $ns_key, $ns_ip );
                }
            }
            # Problem: Can't create an Engine::Nameserver object without an IP address... So we have to mix Engine::Nameserver and Engine::DNSName objects in the same array.
            else {
                push @ib_ns, name( $ns_key );
            }
        }

        return [ @ib_ns ];
    }
    elsif ( scalar keys %aa_ns ) {
        for my $ns_key ( keys %aa_ns ) {
            if ( scalar @{ $aa_ns{$ns_key} } ) {
                for my $ns_ip ( uniq @{ $aa_ns{$ns_key} } ) {
                    push @ib_ns, ns( $ns_key, $ns_ip );
                }
            }
            # Problem: Can't create an Engine::Nameserver object without an IP address... So we have to mix Engine::Nameserver and Engine::DNSName objects in the same array.
            else {
                push @ib_ns, name( $ns_key );
            }
        }

        return [ @ib_ns ];
    }
    else {
        return [ ];
    }
}

=over

=item get_del_ns_names_and_ips($zone)

[External]

This Method will obtain the name server names (from the NS records) and the IP addresses (from Glue Records) from the delegation of the given zone from the parent zone.
Glue Records, if any, are address records for name server names. Also obtain the IP addresses for the Out-Of-Bailiwick name server names, if any.
If the Glue Records include address records for Out-Of-Bailiwick name servers they will be included twice, unless identical.

Takes a L<Zonemaster::Engine::Zone> object.

Returns an arrayref of L<Zonemaster::Engine::Nameserver> objects for each name server name that was successfully resolved to an IP address,
and L<Zonemaster::Engine::DNSName> objects for each name server name that could not be resolved to an IP address, or C<undef> if no parent zone was found.

=back

=cut

sub get_del_ns_names_and_ips {
    my ( $class, $zone ) = @_;

    my $ns_ref = $class->_get_delegation( $zone );

    return undef if not defined $ns_ref;

    my @ns_names = grep { $_->isa('Zonemaster::Engine::DNSName') } @{ $ns_ref };

    my $oob_ns_ref = $class->_get_oob_ips( $zone, \@ns_names );

    @{ $ns_ref } = grep { $_->isa('Zonemaster::Engine::Nameserver') } @{ $ns_ref };

    return [ sort (@{ $ns_ref }, @{ $oob_ns_ref }) ];
}

=over

=item get_del_ns_names($zone)

[External]

This Method will obtain the name server names of the given zone as defined in the delegation from parent zone.

Takes a L<Zonemaster::Engine::Zone> object.

Returns an arrayref of strings, or C<undef> if no parent zone was found.

=back

=cut

sub get_del_ns_names {
    my ( $class, $zone ) = @_;

    my $ns_ref = $class->get_del_ns_names_and_ips( $zone );

    return undef if not defined $ns_ref;

    @{ $ns_ref } = grep { $_->isa('Zonemaster::Engine::Nameserver') } @{ $ns_ref };

    return [ uniq sort map { $_->name->string } @{ $ns_ref } ];
}

=over

=item get_del_ns_ips($zone)

[External]

This Method will obtain the IP addresses (from Glue Records) from the delegation of the given zone from the parent zone.
Glue Records are address records for In-Bailiwick name server names, if any. Also obtain the IP addresses for the Out-Of-Bailiwick name server names, if any.

Takes a L<Zonemaster::Engine::Zone> object.

Returns an arrayref of strings, or C<undef> if no parent zone was found.

=back

=cut

sub get_del_ns_ips {
    my ( $class, $zone ) = @_;

    my $ns_ref = $class->get_del_ns_names_and_ips( $zone );

    return undef if not defined $ns_ref;

    @{ $ns_ref } = grep { $_->isa('Zonemaster::Engine::Nameserver') } @{ $ns_ref };

    return [ uniq sort map { $_->address->short } @{ $ns_ref }];
}

=over

=item get_zone_ns_names($zone)

[External]

This Method will obtain the names of the authoritative name servers for the given zone as defined in the NS records in the zone itself.

Takes a L<Zonemaster::Engine::Zone> object.

Returns an arrayref of strings, or C<undef> if no parent zone was found.

=back

=cut

sub get_zone_ns_names {
    my ( $class, $zone ) = @_;

    # 'get_del_ns_names_and_ips' instead of 'get_del_ns_ips', because we need Zonemaster::Engine::Nameserver objects to be able to do queries.
    my $ns_ref = $class->get_del_ns_names_and_ips( $zone );

    return undef if not defined $ns_ref;

    my @ns_names;

    for my $ns ( @{ $ns_ref } ) {
        my $p = $ns->query( $zone->name, q{NS} );

        if ( $p and $p->aa and $p->rcode eq q{NOERROR} ) {
            push @ns_names, $p->get_records_for_name( q{NS}, $zone->name->string, q{answer} );
        }
    }

    return [ uniq sort map { name( lc( $_->nsdname ) ) } @ns_names ];
}

=over

=item _get_ib_addr_in_zone($zone)

[Internal]

This Method will obtain obtain the address records matching the In-Bailiwick name server names from the given zone.

Takes a L<Zonemaster::Engine::Zone> object.

Returns an arrayref of L<Zonemaster::Engine::Nameserver> objects, or C<undef> if no parent zone was found.

=back

=cut

sub _get_ib_addr_in_zone {
    my ( $class, $zone ) = @_;

    # 'get_del_ns_names_and_ips' instead of 'get_del_ns_ips', because we need Zonemaster::Engine::Nameserver objects to be able to do queries.
    my $del_ips_ref = $class->get_del_ns_names_and_ips( $zone );
    my $ns_names_ref = $class->get_zone_ns_names( $zone );

    return undef if not defined $del_ips_ref or not defined $ns_names_ref or not scalar @{ $del_ips_ref } or not scalar @{ $ns_names_ref };

    return [] if not scalar grep { $zone->name->is_in_bailiwick( $_ ) } @{ $ns_names_ref };

    my %ib_ns;

    for my $ns_name ( @{ $ns_names_ref } ) {
        if ( $zone->name->is_in_bailiwick( $ns_name ) ) {
            for my $ns ( @{ $del_ips_ref } ) {
                for my $qtype ( q{A}, q{AAAA} ) {
                    my ( $p, $state ) = Zonemaster::Engine::Recursor->_recurse( $ns_name, $qtype, q{IN}, { ns => [ $ns ], count => 0, common => 0, seen => {}, glue => {} } );

                    if ( $p and $p->aa and $p->rcode eq q{NOERROR} and $p->has_rrs_of_type_for_name( $qtype, $ns_name ) ) {
                        for my $rr ( $p->get_records_for_name( $qtype, $ns_name ) ) {
                            push @{ $ib_ns{$ns_name} }, $rr->address;
                        }
                    }
                }
            }
        }
    }

    my @ib_ns_array;

    for my $ns_name ( keys %ib_ns ) {
        for my $ns_ip ( uniq @{ $ib_ns{$ns_name} } ) {
            push @ib_ns_array, ns( $ns_name, $ns_ip );
        }
    }

    return [ @ib_ns_array ];
}

=over

=item get_zone_ns_names_and_ips($zone)

[External]

This Method will obtain the name server names (extracted from the NS records) from the apex of the given zone.
For the In-Bailiwick name server names obtain the IP addresses from the given zone. For the Out-Of-Bailiwick name server names obtain the IP addresses from recursive lookup.

Takes a L<Zonemaster::Engine::Zone> object.

Returns an arrayref of L<Zonemaster::Engine::Nameserver> objects for each name server name that was successfully resolved to an IP address,
and L<Zonemaster::Engine::DNSName> objects for each name server name that could not be resolved to an IP address, or C<undef> if no parent zone was found.

=back

=cut

sub get_zone_ns_names_and_ips {
    my ( $class, $zone ) = @_;

    my $ns_names_ref = $class->get_zone_ns_names( $zone );

    return undef if not defined $ns_names_ref;

    return [] if not scalar @{ $ns_names_ref };

    my $ib_ns_ref = $class->_get_ib_addr_in_zone( $zone );
    my $oob_ns_ref = $class->_get_oob_ips( $zone, $ns_names_ref );

    my @zone_ns;

    for my $ns_name ( @{ $ns_names_ref } ) {
        if ( $zone->name->is_in_bailiwick( $ns_name ) ) {
            for my $ib_ns ( @{ $ib_ns_ref } ) {
                if ( $ns_name->string eq $ib_ns->name->string ) {
                    push @zone_ns, ns( $ns_name, $ib_ns->address->short);
                }
            }
        }
        else {
            for my $oob_ns ( @{ $oob_ns_ref } ) {
                if ( $oob_ns->isa('Zonemaster::Engine::Nameserver') and $ns_name->string eq $oob_ns->name->string ) {
                    push @zone_ns, ns( $ns_name, $oob_ns->address->short);
                }
                elsif ( $oob_ns->isa('Zonemaster::Engine::DNSName') and $ns_name->string eq $oob_ns->string ) {
                    push @zone_ns, $ns_name;
                }
            }
        }
    }

    return [ @zone_ns ];
}

=over

=item get_zone_ns_ips($zone)

[External]

This Method will obtain the IP addresses of the name servers, as extracted from the NS records of apex of the given zone.

Takes a L<Zonemaster::Engine::Zone> object.

Returns an arrayref of strings, or C<undef> if no parent zone was found.

=back

=cut

sub get_zone_ns_ips {
    my ( $class, $zone ) = @_;

    my $ns_ref = $class->get_zone_ns_names_and_ips( $zone );

    return undef if not defined $ns_ref;

    return [ map { $_->address->short } @{ $ns_ref } ];
}

1;
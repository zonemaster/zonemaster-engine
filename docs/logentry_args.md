# Types of information in Zonemaster log objects

## Aggregate list

| Argument    | Type of value        | Description and formatting                                  |
|-------------|----------------------|-------------------------------------------------------------|
| nsname      | Domain name          | The domain name of a name server.                           |
| ns_ip       | IP address           | The IP address of a name server.                            |
| ns          | Domain name and IP address pair | The name and IP address of a name server, separated by "/". |
| nsname_list | List of domain names | A list of name servers, as specified by "nsname", separated by ";". |
| ns_ip_list  | List of IP addresses | A list of name servers, as specified by "ns_ip", separated by ";". |
| ns_list     | List of domain name and IP address pairs | A list of name servers, as specified by "ns", separated by ";". |
|| AS number| An Autonomous Space number for an IP address.|
|| Address record type (A or AAAA)| Used to tell the difference between IPv4 and IPv6.|
|| Count of different SOA RNAMEs.| Total number of different SOA RNAME fields seen.|
|| Count of different SOA serial numbers| Total number of different SOA serial numbers seen.|
|| Count of different sets of NS name/IP seen.| Total number of different sets of nameserver information seen.|
|| Count of different time parameter sets seen| Total number of different sets of SOA time parameters seen.|
|| Count of domain names| A count of domain names.|
|| Count of nameservers| A count of nameservers.|
|| DNS packet size| The size in octets of a DNS packets.|
|| DNSKEY algorithm name| The name of a DNSKEY algorithm.|
|| DNSKEY algorithm number| The numeric value for a DNSKEY algorithm.|
|| DNSKEY key length| The key length for a DNSKEY. The interpretation of this value various quite a bit with the algorithm. Be careful when using it for algorithms that aren't RSA-based.|
|| DNSSEC delegation verification failure reason| A somewhat human-readable reason why the delegation step between the tested zone and its parent is not secure.|
|| DS digest type| The digest type used in a DS record.|
|| DS/DNSKEY/RRSIG keytag| A keytag for a DS, DNSKEY or RRSIG record.|
| dname (?) | Domain name| A domain name.|
| dlabel (?) | Domain name label| A single label from a domain name.|
| dlength (?) | Domain name label length| The length of a domain name label.|
|| Duration in seconds| An integer number of seconds.|
| fqdn (?) | FQDN| A fully qualified domain name (with terminating dot).|
| fqdnlength (?) | FQDN length| The length of an FQDN.|
|| IP address| An IPv4 or IPv6 address.|
|| IP address or nothing| An IPv4 or IPv6 address, or no value.|
|| IP range| An IP range.|
|| IP reserved range description| A brief description what an IP range is reserved for.|
|| Largest SOA serial number seen| The numerically largest SOA serial value seen.|
|| List of AS numbers| A list of Autonomous Space numbers.|
|| List of DNSKEY keytags| A list of keytags from DNSKEY records.|
|| List of DS keytags| A list of keytags from DS records.|
|| List of DS/DNSKEY/RRSIG keytags| A list of keytags from DS, DNSKEY or RRSIG records.|
|| List of IP addresses| A list of IP addresses.|
|| List of MX domain names| A list of domain names from MX records.|
|| List of RR types| A list of RR types, typically from an NSEC or NSEC3 record.|
|| List of SOA RNAMEs| A list of RNAME values from SOA records.|
|| List of SOA serial numbers| A list of serial number values from SOA records.|
|| List of domain names| A list of domain names.|
|| NS names from child| A list of nameserver names taken from a zone's child servers.|
|| NS names from parent| A list of nameserver names taken from a zone's parent servers.|
|| NSEC3 iteration count| An iteration count from an NSEC3PARAM record.|
|| Number of DNSKEY RRs in packet| The number of DNSKEY records found in a packet.|
|| Number of RRSIG RRs in packet| The number of RRSIG records found in a packet.|
|| Number of SOA RRs in packet| The number of SOA records found in a packet.|
|| PTR query name| The domain name generated from an IP address for a reverse name lookup.|
| pname (?) | Parent zone name| The name of a tested zone's parent zone.|
|| Protocol (UDP or TCP)| The protocol used for a query.|
| rcode (?) | RCODE| An RCODE from a DNS packet.|
|| RFC reference| A reference to an RFC.|
| rrtype (?) | RR type| The type of RR the message pertains to.|
|| RRSIG Expiration date| The time when a signature expires.|
|| RRSIG validation error message| The human-readable reason why the cryptographic validation of a signature failed.|
|| SOA MNAME| The MNAME value from a SOA record.|
|| SOA RNAME| The RNAME value from a SOA record.|
|| SOA expire| The expire value from a SOA record.|
|| SOA expire minimum value| The lowest value considered OK for the SOA expire field.|
|| SOA minimum| The minimum value from a SOA record.|
|| SOA minimum maximum value| The highest value considered OK for the SOA minimum field.|
|| SOA minimum minimum value| The lowest value considered OK for the SOA minimum field.|
|| SOA refresh| The refresh value from a SOA record.|
|| SOA refresh minimum value| The lowest value considered OK for the SOA refresh field.|
|| SOA retry| The retry value from a SOA record.|
|| SOA retry minimum value| The lowest value considered OK for the SOA retry field.|
|| SOA serial number| The serial number value from a SOA record.|
|| Smallest SOA serial number seen| The smallest value seen in a SOA serial field in the tested zone.|
|| TLD| The name of a top-level domain.|
|| `time_t` value when RRSIG validation was attempted| The time when an RRSIG validation was attempted, in Unix `time_t` format.|
| zname (?) | Zone name| The domain name of the zone being tested.|

Message names maked with a question mark should not be considered stable.


## List by test module

### Basic

* Domain name

* Domain name label

* Domain name label length

* FQDN

* FQDN length

* Zone name

* Parent zone name

* NS names from parent

* RCODE

* Nameserver name/IP pair

* NS names from child

* RR type

### Address

* Nameserver name

* Nameserver IP

* IP reserved range description

* RFC reference

* IP range

* PTR query name

* List of domain names

### Connectivity

* Nameserver name/IP pair

* RR type

* Nameserver name

* Nameserver IP

* List of AS numbers

* AS number

### Consistency

* Nameserver name/IP pair

* RR type

* Nameserver name

* Nameserver IP

* SOA serial number

* Count of different SOA serial numbers

* List of SOA serial numbers

* Smallest SOA serial number seen

* Largest SOA serial number seen

* SOA RNAME

* Count of different SOA RNAMEs.

* List of SOA RNAMEs.

* SOA refresh

* SOA retry

* SOA expire

* SOA minimum

* Count of different time parameter sets seen

* List of domain names

* List of nameserver name/IP pairs.

* Count of different sets of NS name/IP seen.

### Delegation

* Count of nameservers

* List of domain names

* IP address

* List of IP addresses

* DNS packet size

* Nameserver name/IP pair

* RR type

* Domain name

* Protocol (UDP or TCP)

* Address record type (A or AAAA)

* Count of domain names

### DNSSEC

* Zone name

* IP address

* DS/DNSKEY/RRSIG keytag

* DS digest type

* List of DS/DNSKEY/RRSIG keytags

* List of DS keytags

* List of DNSKEY keytags

* IP address or nothing

* NSEC3 iteration count

* DNSKEY key length

* RRSIG Expiration date

* List of RR types

* Duration in seconds

* DNSKEY algorithm number

* DNSKEY algorithm name

* Number of DNSKEY RRs in packet

* Number of RRSIG RRs in packet

* time_t value when RRSIG validation was attempted

* RRSIG validation error message

* Number of SOA RRs in packet

* RCODE

* DNSSEC delegation verification failure reason

### Nameserver

* Nameserver name

* Nameserver IP

* Domain name

* List of nameserver names

* List of nameserver name/IP pairs

* RR type

* Nameserver name/IP pair

* RCODE

### Syntax

* Domain name

* Domain name label

* SOA RNAME

* TLD

### Zone

* SOA MNAME

* Nameserver IP

* Nameserver name

* Zone name

* List of nameserver name/IP pairs

* SOA refresh

* SOA refresh minimum value

* SOA retry

* SOA retry minimum value

* SOA expire

* SOA expire minimum value

* SOA minimum

* SOA minimum maximum value

* SOA minimum minimum value

* List of MX domain names


# Argument names for test case messages


## Introduction

This document defines arguments names, and their type of value, for the
Zonemaster messages. The messages are defined in the Perl modules for the test
cases, e.g. [Basic.pm], and translated in the PO files, e.g. [fr.po] and [sv.po].
The arguments are used in the messages, and are there put within curly brackets,
e.g. as `{ns}`.

When a message is created or updated only argument names defined in this document
should be used. If there is defined argument name that can be used for the
message then a new argument name must be defined and this document is to be
updated.

## Multiple argument of the same type

In the same message an argument name can only be used once. In a case that more
than one is needed the name can be extended in the following way without adding
the extended name to this document. The extension is done by adding "_" plus some
relevant string in lower case "a-z0-9".

As an example, if two arguments of type "List of IP addresses" are to be used in
a message, then both argument base names should `ns_ip_list`. Let us say that one
is connected to the NSEC record type and the other to the NSEC3 record type. The
two argument names could then be `ns_ip_list_nsec` and `ns_ip_list_nsec3`,
respectively.

Example of use:

> The zone is inconsistent on NSEC and NSEC3. NSEC is fetched from nameservers
> with IP addresses "{ns_ip_list_nsec}". NSEC3 is fetched from nameservers
> with IP addresses "{ns_ip_list_nsec3}".




## Defined argument names

When a suitable name and type of value is found in this list, it should also be
used in new and updated messages.

| Argument name  | Type of value                      | Description and formatting                                  |
|--------------- |------------------------------------|-------------------------------------------------------------|
| algo_descr     | Text                               | The human readable description of a [DNSSEC algorithm].     |
| algo_mnemo     | Text                               | The mnemonic of a [DNSSEC algorithm].                       |
| algo_num       | Non-negative integer               | The numeric value for a [DNSSEC algorithm].                 |
| domain         | Domain name                        | A domain name. If nsname is also applicable, use that one instead.|
| keytag         | Non-negative integer               | A keytag for a DNSKEY record or a keytag used in a DS or RRSIG record.|
| mailtarget     | Domain name                        | The domain name of the mailserver in an MX RDATA.           |
| mailtarget_list| List of domain names               |A list of name servers, as specified by "mailtarget", separated by ";".|
| module         | A Zonemaster test module, or `all` | The name of a Zonemaster test module.                       |
| module_list    | List of Zonemaster test modules    | A list of Zonemaster test modules, separated by ":".        |
| ns             | Domain name and IP address pair    | The name and IP address of a name server, separated by "/". |
| ns_ip          | IP address                         | The IP address of a name server.                            |
| ns_ip_list     | List of IP addresses               | A list of name servers, as specified by "ns_ip", separated by ";".|
| ns_list        | List of domain name and IP address pairs | A list of name servers, as specified by "ns", separated by ";".|
| nsname         | Domain name                        | The domain name of a name server.                           |
| nsname_list    | List of domain names               | A list of name servers, as specified by "nsname", separated by ";".|
| testcase       | A Zonemaster test case, or `all`   | A test case identifier.                                     |


## Preliminary or proposed names or types

The names in in this are not fully defined. If used it should follow the pattern
of defined argument names, be fully defined and moved to the list of defined
argument names.

| Argument name  | Type of value                      | Description and formatting                                  |
|--------------- |------------------------------------|-------------------------------------------------------------|
|| AS number| An Autonomous Space number for an IP address.|
|| Address record type (A or AAAA)| Used to tell the difference between IPv4 and IPv6.|
|| Count of different SOA RNAMEs.| Total number of different SOA RNAME fields seen.|
|| Count of different SOA serial numbers| Total number of different SOA serial numbers seen.|
|| Count of different sets of NS name/IP seen.| Total number of different sets of nameserver information seen.|
|| Count of different time parameter sets seen| Total number of different sets of SOA time parameters seen.|
|| Count of domain names| A count of domain names.|
|| Count of nameservers| A count of nameservers.|
|| DNS packet size| The size in octets of a DNS packets.|
|| DNSKEY key length| The key length for a DNSKEY. The interpretation of this value various quite a bit with the algorithm. Be careful when using it for algorithms that aren't RSA-based.|
|| DNSSEC delegation verification failure reason| A somewhat human-readable reason why the delegation step between the tested zone and its parent is not secure.|
|| DS digest type| The digest type used in a DS record.|
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

Message names maked with a question mark should not be considered stable.


[Basic.pm]:                                  ../lib/Zonemaster/Engine/Test/Basic.pm
[DNSSEC algorithm]:                          https://www.iana.org/assignments/dns-sec-alg-numbers/dns-sec-alg-numbers.xhtml
[fr.po]:                                     ../share/fr.po
[sv.po]:                                     ../share/fr.po

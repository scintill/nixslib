# This file is originally from https://github.com/alexandroskoliousis/iana-ports/blob/master/process_iana.awk
# The original author is Alexandros Koliousis. The file was offered under the Apache 2.0 License.
#
# It has been modified by Joey Hewitt to output an Nix attribute set with service names as keys,
# and numbers as values.


# Process IANA port list -
# 
# a) save IANA's port-numbers file as <filename>; then
# b) run "cat <filename> | awk -f process_iana.awk" or
# c) awk -f process_iana.awk <filename 1> ... <filename n>
# 
# Outputs "tcp_ports.nix" and "udp_ports.nix".

# main
BEGIN{
# Look for duplicates. (A tcp/udp port is assigned to a single app;
# but an app can use more than one ports.) Also, distinguish between
# tcp and udp ports.
prev = -1
tcp_file = "tcp_ports.nix"
print "{" > tcp_file
udp_file = "udp_ports.nix"
print "{" > udp_file
}
# Narrow down the search: look for <number>/<tcp> or <number>/<udp>.
/[0-9]*\/["udp","tcp"]/ {
# Ignore all comments
if (substr($1,1,1) == "#") {next}
# print $0
# Look for
# <short description> <port number>/<tcp or udp> <long description>
a_file = tcp_file
for (i=1; i<=NF; i++) {
	# The benefit here is that <number>/<tcp> appears as a single string.
	# valid = substr($i, index($i,"/")+1, length($i))
	split($i, s, "/")
	valid = s[2]
	if (valid == "tcp" || valid == "udp") {
	if (valid == "udp") 
	{a_file = udp_file}
	# port = substr($i,0,match($i,"/"))
	port = s[1]
	if (match(port, "^[0-9]+$")) {
		isDuplicate = 0
		# Check for duplicates:
		if (valid == "tcp")
		{
			tcp_duplicate[$1]++
			if (tcp_duplicate[$1] > 1)
			{
printf("Warning: found duplicate TCP service. Previous entry was in line %d. Ignoring line %d:\n%s\n",
	tcp_prev_line[port], NR, $0)
isDuplicate = 1
			}
			tcp_prev_line[port]=NR
		}
		else if (valid == "udp") 
		{
			udp_duplicate[$1]++
			if (udp_duplicate[$1] > 1) 
			{
printf("Warning: found duplicate UDP port. Previous entry was in line %d. Ignoring line %d:\n%s\n",
	udp_prev_line[port], NR, $0)
isDuplicate = 1
			}
			udp_prev_line[port]=NR
		}
		if (isDuplicate == 0)
		{	# Process as new;
			if (i == 2) 
			{printf("\"%s\"=%s;\n", $1, port) >> a_file}
			else 
			{ # Use long description instead.
			long_descr = substr($0, match($0,"\/[tcp,udp]")+1+3)
			gsub(" ","_",long_descr)
			printf("\"%s\"=%s;\n", long_descr, port) >> a_file
			}
		}
	}
	} # end if (tcp or udp)
} # end for
} # end of main._
END {
print "}" > tcp_file
print "}" > udp_file
}

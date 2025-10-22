# SOA reverse: harus sama di ns1 & ns2
dig +norecurse @192.231.3.2 3.231.192.in-addr.arpa SOA +short
dig +norecurse @192.231.3.3 3.231.192.in-addr.arpa SOA +short

# PTR (authoritative) dari keduanya
for NS in 192.231.3.2 192.231.3.3; do
  echo "== NS $NS =="
  dig +norecurse @$NS -x 192.231.3.6 +noall +answer +cmd
  dig +norecurse @$NS -x 192.231.3.4 +noall +answer +cmd
  dig +norecurse @$NS -x 192.231.3.5 +noall +answer +cmd
done

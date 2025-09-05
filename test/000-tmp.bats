load helpers


HELPER_PID=
function teardown() {
	if [[ -n "$HELPER_PID" ]]; then
		kill -9 $HELPER_PID
	fi
	basic_teardown
}

# @test "reload resolv.conf" {
#     setup_dnsmasq
#     	# Set up second dnsmasq server to simulate second DNS server
# 	run_in_host_netns dnsmasq --conf-file=/dev/null --pid-file="$AARDVARK_TMPDIR/dnsmasq_second.pid" \
# 		--except-interface=lo --listen-address=127.1.1.2 --bind-interfaces --port=5354 \
# 		--address=/second-server.test/192.168.100.2 --no-resolv --no-hosts
# 	HELPER_PID=$(cat $AARDVARK_TMPDIR/dnsmasq_second.pid)

#     subnet_a=$(random_subnet 5)
# 	create_config network_name="podman1" container_id=$(random_string 64) container_name="aone" subnet="$subnet_a" custom_dns_server='"127.0.0.255"' aliases='"a1", "1a"'
# 	config_a1=$config
# 	ip_a1=$(echo "$config_a1" | jq -r .networks.podman1.static_ips[0])
# 	gw=$(echo "$config_a1" | jq -r .network_info.podman1.subnets[0].gateway)
# 	create_container "$config_a1"
# 	a1_pid=$CONTAINER_NS_PID
#     cat "$AARDVARK_TMPDIR/resolv.conf"
# 	run_in_container_netns "$a1_pid" "dig" "+short" "aone" "@$gw"
#     echo "output: $output"
#     	# Update resolv.conf to point to second DNS server
# 	cat > "$AARDVARK_TMPDIR/resolv.conf" <<EOF
# nameserver 127.1.1.2
# options port:5354
# EOF
#     expected_rc=124 run_in_container_netns "$a1_pid" "host" "-t" "a" "second-server.test" "$gw"
# 	echo "output: $output"
# }
@test "nameservers updated when resolv.conf is modified" {
	setup_dnsmasq

	# Set up first dnsmasq server on standard port 53 with unique IP
	# run_in_host_netns dnsmasq --conf-file=/dev/null --pid-file="$AARDVARK_TMPDIR/dnsmasq_first.pid" \
	# 	--except-interface=lo --listen-address=127.1.1.1 --bind-interfaces \
	# 	--address=/first-server.test/192.168.100.1 --no-resolv --no-hosts
	# FIRST_DNS_PID=$(cat $AARDVARK_TMPDIR/dnsmasq_first.pid)

	# Set up second dnsmasq server on standard port 53 with different IP
	run_in_host_netns dnsmasq --conf-file=/dev/null --pid-file="$AARDVARK_TMPDIR/dnsmasq_second.pid" \
		--except-interface=lo --listen-address=127.1.1.2 --bind-interfaces \
		--address=/second-server.test/192.168.100.2 --no-resolv --no-hosts
	SHELPER_PID=$(cat $AARDVARK_TMPDIR/dnsmasq_second.pid)

# 	# Create initial resolv.conf pointing to first DNS server
# 	cat > "$AARDVARK_TMPDIR/resolv.conf" <<EOF
# nameserver 127.1.1.1
# EOF

	# # Bind mount our custom resolv.conf
	# run_in_host_netns mount --bind "$AARDVARK_TMPDIR/resolv.conf" /etc/resolv.conf

	# Set up container
	subnet_a=$(random_subnet 5)
	create_config network_name="podman1" container_id=$(random_string 64) container_name="aone" subnet="$subnet_a"
	config_a1=$config
	gw=$(echo "$config_a1" | jq -r .network_info.podman1.subnets[0].gateway)
	create_container "$config_a1"
	a1_pid=$CONTAINER_NS_PID


	# Test that we can resolve using the first DNS server
	run_in_container_netns "$a1_pid" "dig" "+short" "testname" "@$gw"
	assert "$output" == "198.51.100.1" "should resolve using first DNS server"

	# Verify we cannot resolve second server's domain yet
	expected_rc=1 run_in_container_netns "$a1_pid" "host" "-t" "a" "second-server.test" "$gw"
	assert "$output" =~ "not found" "should not resolve second server's domain initially"

	# Update resolv.conf to point to second DNS server
	cat > "$AARDVARK_TMPDIR/resolv.conf" <<EOF
nameserver 127.1.1.2
EOF

# 	# Give aardvark time to detect the change and update nameservers
	sleep 3

	# Test that we can now resolve using the second DNS server
	run_in_container_netns "$a1_pid" "dig" "+short" "second-server.test" "@$gw"
	assert "$output" == "192.168.100.2" "should resolve using second DNS server after resolv.conf change"

# 	# Verify we cannot resolve first server's domain anymore
# 	expected_rc=1 run_in_container_netns "$a1_pid" "host" "-t" "a" "first-server.test" "$gw"
# 	assert "$output" =~ "not found" "should not resolve first server's domain after change"

}

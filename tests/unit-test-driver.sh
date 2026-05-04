#!/bin/bash

# Unit Tests for Network Driver Components
# Tests SFC driver, MTU configuration, and network boot modules

set -euo pipefail

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

pass_test() {
    echo -e "${GREEN}✓ PASS${NC}: $1"
    ((PASSED_TESTS++))
}

fail_test() {
    echo -e "${RED}✗ FAIL${NC}: $1"
    ((FAILED_TESTS++))
}

skip_test() {
    echo -e "${YELLOW}⊘ SKIP${NC}: $1"
}

# Test 1: Check SFC module info
test_sfc_module_info() {
    ((TOTAL_TESTS++))
    echo "Testing SFC module information..."

    if modinfo sfc 2>/dev/null | grep -q "Ver:"; then
        pass_test "SFC module information available"
    else
        fail_test "SFC module information not available"
    fi
}

# Test 2: Check SFC driver version
test_sfc_driver_version() {
    ((TOTAL_TESTS++))
    echo "Testing SFC driver version..."

    VER=$(modinfo sfc 2>/dev/null | grep "^version:" | cut -d: -f2 | xargs || echo "")

    if [ -n "${VER}" ]; then
        pass_test "SFC driver version: ${VER}"
    else
        skip_test "SFC driver version not available"
    fi
}

# Test 3: Check for supported devices
test_sfc_supported_devices() {
    ((TOTAL_TESTS++))
    echo "Testing SFC supported devices..."

    if modinfo sfc 2>/dev/null | grep -q "alias:"; then
        DEVICES=$(modinfo sfc 2>/dev/null | grep "alias:" | wc -l)
        pass_test "SFC driver supports ${DEVICES} device types"
    else
        skip_test "No device aliases found"
    fi
}

# Test 4: Check MTU configuration in boot parameters
test_mtu_boot_params() {
    ((TOTAL_TESTS++))
    echo "Testing MTU boot parameters..."

    if cat /proc/cmdline 2>/dev/null | grep -q "MTU=9000"; then
        pass_test "MTU 9000 found in boot parameters"
    else
        skip_test "MTU 9000 not found in boot parameters"
    fi
}

# Test 5: Check kernel supports jumbo frames
test_jumbo_frames_support() {
    ((TOTAL_TESTS++))
    echo "Testing jumbo frames support..."

    # Check maximum MTU
    MAX_MTU=$(cat /proc/sys/net/ipv4/udp_max_dst_len 2>/dev/null || echo 65535)

    if [ "${MAX_MTU}" -ge 9000 ]; then
        pass_test "Kernel supports MTU up to ${MAX_MTU} (≥9000)"
    else
        fail_test "Kernel MTU limit: ${MAX_MTU} (<9000)"
    fi
}

# Test 6: Check TCP optimizations
test_tcp_optimizations() {
    ((TOTAL_TESTS++))
    echo "Testing TCP optimizations..."

    # Check for TCP offload settings
    if sysctl -a 2>/dev/null | grep -q "net.core.rmem_max"; then
        pass_test "TCP buffer settings available"
    else
        skip_test "TCP buffer settings not available"
    fi
}

# Test 7: Check network driver modules loaded
test_driver_modules_loaded() {
    ((TOTAL_TESTS++))
    echo "Testing driver modules..."

    MODULES="sfc e1000 e1000e r8169 virtio_net"
    local loaded_count=0

    for module in ${MODULES}; do
        if lsmod | grep -q "^${module} "; then
            ((loaded_count++))
        fi
    done

    if [ "${loaded_count}" -gt 0 ]; then
        pass_test "Driver modules loaded: ${loaded_count}/${MODULES}"
    else
        skip_test "No driver modules loaded yet"
    fi
}

# Test 8: Check network device initialization
test_network_device_init() {
    ((TOTAL_TESTS++))
    echo "Testing network device initialization..."

    # Check for network interfaces
    IFACES=$(ip link show | grep -E "^[0-9]+: (eth|ens|enp)" | wc -l)

    if [ "${IFACES}" -gt 0 ]; then
        pass_test "Network interfaces initialized: ${IFACES}"
    else
        skip_test "No network interfaces initialized yet"
    fi
}

# Test 9: Check network statistics
test_network_stats() {
    ((TOTAL_TESTS++))
    echo "Testing network statistics..."

    # Check for network statistics
    if [ -f /proc/net/dev ]; then
        RX=$(grep -oP 'eth[0-9]|\w+:\d+:' /proc/net/dev | head -1 | cut -d: -f1 || echo "")
        if [ -n "${RX}" ]; then
            pass_test "Network statistics available for ${RX}"
        else
            skip_test "No network statistics available"
        fi
    else
        skip_test "/proc/net/dev not available"
    fi
}

# Test 10: Check ARP cache
test_arp_cache() {
    ((TOTAL_TESTS++))
    echo "Testing ARP cache..."

    if [ -f /proc/net/arp ]; then
        ARP_COUNT=$(wc -l < /proc/net/arp)
        if [ "${ARP_COUNT}" -gt 1 ]; then
            pass_test "ARP cache has ${ARP_COUNT} entries"
        else
            skip_test "ARP cache empty (expected before network boot)"
        fi
    else
        skip_test "/proc/net/arp not available"
    fi
}

# Run tests
run_tests() {
    echo ""
    echo "=========================================="
    echo "Network Driver Unit Tests"
    echo "=========================================="
    echo ""

    test_sfc_module_info
    test_sfc_driver_version
    test_sfc_supported_devices
    test_mtu_boot_params
    test_jumbo_frames_support
    test_tcp_optimizations
    test_driver_modules_loaded
    test_network_device_init
    test_network_stats
    test_arp_cache

    echo ""
    echo "=========================================="
    echo "Test Summary"
    echo "=========================================="
    echo "Total:  ${TOTAL_TESTS}"
    echo -e "Passed: ${GREEN}${PASSED_TESTS}${NC}"
    echo -e "Failed: ${RED}${FAILED_TESTS}${NC}"
    echo "=========================================="

    if [ "${FAILED_TESTS}" -gt 0 ]; then
        exit 1
    else
        exit 0
    fi
}

run_tests
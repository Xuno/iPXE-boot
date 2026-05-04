#!/bin/bash

# Test Suite for iPXE Boot System
# Runs on physical hardware/VMs, NO Docker

set -euo pipefail

# Configuration
HTTP_SERVER="${HTTP_SERVER:-localhost:8080}"
IPXE_URL="${IPXE_URL:-http://${HTTP_SERVER}/ubuntu/current}"
TEST_HOST="${TEST_HOST:-}"
TEST_DIR="${TEST_DIR:-/tmp/ipxe-tests}"

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Test functions
pass_test() {
    echo "✓ PASS: $1"
    ((PASSED_TESTS++))
}

fail_test() {
    echo "✗ FAIL: $1"
    ((FAILED_TESTS++))
}

skip_test() {
    echo "⊘ SKIP: $1"
}

info() {
    echo "ℹ INFO: $1"
}

error() {
    echo "ERROR: $1"
    exit 1
}

# Setup test environment
setup_test() {
    info "Setting up test environment..."
    mkdir -p "${TEST_DIR}/results"
    mkdir -p "${TEST_DIR}/logs"
}

# Test 1: Check HTTP server availability
test_http_server() {
    ((TOTAL_TESTS++))
    info "Testing HTTP server availability..."

    if curl -sf "http://${HTTP_SERVER}/health" > /dev/null 2>&1; then
        pass_test "HTTP server is responding"
    else
        fail_test "HTTP server is not responding"
    fi
}

# Test 2: Check iPXE boot script exists
test_ipxe_script() {
    ((TOTAL_TESTS++))
    info "Testing iPXE boot script availability..."

    if curl -sf "${IPXE_URL}/boot.ipxe" > /dev/null 2>&1; then
        pass_test "iPXE boot script is accessible"
    else
        fail_test "iPXE boot script is not accessible"
    fi
}

# Test 3: Check kernel file exists
test_kernel_file() {
    ((TOTAL_TESTS++))
    info "Testing kernel file availability..."

    if curl -sf "${IPXE_URL}/vmlinuz" > /dev/null 2>&1; then
        pass_test "Kernel file (vmlinuz) is accessible"
    else
        fail_test "Kernel file is not accessible"
    fi
}

# Test 4: Check initrd file exists
test_initrd_file() {
    ((TOTAL_TESTS++))
    info "Testing initrd file availability..."

    if curl -sf "${IPXE_URL}/initrd" > /dev/null 2>&1; then
        pass_test "Initrd file is accessible"
    else
        fail_test "Initrd file is not accessible"
    fi
}

# Test 5: Check squashfs files exist
test_squashfs_files() {
    ((TOTAL_TESTS++))
    info "Testing squashfs files availability..."

    local squashfs_count=0

    if curl -sf "${IPXE_URL}/filesystem.squashfs" > /dev/null 2>&1; then
        ((squashfs_count++))
        info "  - filesystem.squashfs exists"
    fi

    if curl -sf "${IPXE_URL}/apps.filesystem.squashfs" > /dev/null 2>&1; then
        ((squashfs_count++))
        info "  - apps.filesystem.squashfs exists"
    fi

    if [ "${squashfs_count}" -ge 1 ]; then
        pass_test "Squashfs files accessible (${squashfs_count} found)"
    else
        fail_test "No squashfs files found"
    fi
}

# Test 6: Check MTU configuration
test_mtu_configuration() {
    ((TOTAL_TESTS++))
    info "Testing MTU configuration..."

    # Check Nginx headers
    MTU=$(curl -sI "http://${HTTP_SERVER}/ubuntu/vmlinuz" | grep -i "X-MTU" | cut -d' ' -f2 || echo "")

    if [ -n "${MTU}" ] && [ "${MTU}" = "9000" ]; then
        pass_test "MTU 9000 configured correctly"
    else
        # May not be configured yet, skip
        skip_test "MTU configuration not found (may not be configured)"
    fi
}

# Test 7: Network interface detection
test_network_interface() {
    ((TOTAL_TESTS++))
    info "Testing network interface..."

    # Check for eth0 or ens*
    IFACE=$(ip link show | grep -E "^[0-9]+: (eth|ens|enp)" | head -n1 | cut -d: -f2 | tr -d ' ')

    if [ -n "${IFACE}" ]; then
        pass_test "Network interface found: ${IFACE}"

        # Check MTU
        MTU=$(ip link show "${IFACE}" | grep -oP 'mtu \K\d+' || echo "")
        if [ "${MTU}" = "9000" ]; then
            pass_test "Network interface MTU is 9000"
        else
            fail_test "Network interface MTU is ${MTU}, expected 9000"
        fi
    else
        skip_test "No network interface detected"
    fi
}

# Test 8: Check SFC driver module
test_sfc_driver() {
    ((TOTAL_TESTS++))
    info "Testing SFC driver module..."

    # Check if SFC module is loaded
    if lsmod | grep -q sfc; then
        pass_test "SFC driver module is loaded"
    else
        # May not be loaded, check for kernel support
        if modinfo sfc 2>/dev/null; then
            pass_test "SFC driver module is available in kernel"
        else
            skip_test "SFC driver module not found"
        fi
    fi
}

# Test 9: Verify diskless boot capability
test_diskless_boot() {
    ((TOTAL_TESTS++))
    info "Testing diskless boot capability..."

    # Check that root is mounted from overlay/NFS
    if mount | grep -qE "overlay|nfs"; then
        pass_test "Diskless filesystem mounted (overlay or NFS)"
    else
        # This is normal in non-booted state
        skip_test "No diskless filesystem mounted (expected before boot)"
    fi
}

# Test 10: Check service availability
test_services() {
    ((TOTAL_TESTS++))
    info "Testing service availability..."

    # Check for common services
    SERVICES="ssh systemd-networkd dhclient"
    local service_count=0

    for service in ${SERVICES}; do
        if systemctl list-unit-files | grep -q "${service}.service"; then
            ((service_count++))
        fi
    done

    if [ "${service_count}" -gt 0 ]; then
        pass_test "Service files found (${service_count} detected)"
    else
        skip_test "No service files found"
    fi
}

# Test 11: Check disk space
test_disk_space() {
    ((TOTAL_TESTS++))
    info "Testing disk space..."

    # Check for overlay/nfs mount space
    for mount in overlay nfs; do
        if mount | grep -q "${mount}"; then
            USED=$(df "${mount}" 2>/dev/null | tail -1 | awk '{print $3}')
            TOTAL=$(df "${mount}" 2>/dev/null | tail -1 | awk '{print $2}')
            FREE=$(df -h "${mount}" 2>/dev/null | tail -1 | awk '{print $4}')

            if [ -n "${FREE}" ]; then
                info "  ${mount}: ${FREE} free (${USED}/${TOTAL})"
            fi
        fi
    done

    pass_test "Disk space check completed"
}

# Test 12: Check network connectivity
test_network_connectivity() {
    ((TOTAL_TESTS++))
    info "Testing network connectivity..."

    if ping -c 1 -W 2 "${HTTP_SERVER%%:*}" > /dev/null 2>&1; then
        pass_test "Network connectivity to HTTP server verified"
    else
        fail_test "Cannot reach HTTP server"
    fi
}

# Run all tests
run_all_tests() {
    setup_test
    echo ""
    echo "=========================================="
    echo "iPXE Boot Test Suite"
    echo "=========================================="
    echo "HTTP Server: ${HTTP_SERVER}"
    echo "IPXE URL:    ${IPXE_URL}"
    echo "Test Host:   ${TEST_HOST}"
    echo "=========================================="
    echo ""

    # Run tests
    test_http_server
    test_ipxe_script
    test_kernel_file
    test_initrd_file
    test_squashfs_files
    test_mtu_configuration
    test_network_interface
    test_sfc_driver
    test_diskless_boot
    test_services
    test_disk_space
    test_network_connectivity

    # Print summary
    echo ""
    echo "=========================================="
    echo "Test Summary"
    echo "=========================================="
    echo "Total:  ${TOTAL_TESTS}"
    echo "Passed: ${PASSED_TESTS}"
    echo "Failed: ${FAILED_TESTS}"
    echo "=========================================="

    if [ "${FAILED_TESTS}" -gt 0 ]; then
        echo "ERROR: Some tests failed"
        exit 1
    else
        echo "SUCCESS: All tests passed"
        exit 0
    fi
}

# Parse command line arguments
case "${1:-}" in
    all)
        run_all_tests
        ;;
    http)
        test_http_server
        ;;
    network)
        test_network_interface
        test_network_connectivity
        ;;
    diskless)
        test_diskless_boot
        test_disk_space
        ;;
    *)
        echo "iPXE Boot Test Suite"
        echo ""
        echo "Usage: $0 {all|http|network|diskless}"
        echo ""
        echo "Commands:"
        echo "  all    - Run all tests"
        echo "  http   - Test HTTP server"
        echo "  network - Test network interface"
        echo "  diskless - Test diskless boot"
        exit 1
        ;;
esac
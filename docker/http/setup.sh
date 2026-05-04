#!/bin/bash
# Setup script for HTTP server directory structure

set -euo pipefail

# Directories
HTTP_ROOT="/var/www/boots"
UBUNTU_ROOT="${HTTP_ROOT}/ubuntu"
CURRENT_LINK="${UBUNTU_ROOT}/current"

# Create directories
mkdir -p "${UBUNTU_ROOT}"
mkdir -p "${HTTP_ROOT}/root"

# Create current symlink placeholder
if [ ! -L "${CURRENT_LINK}" ]; then
    ln -sf "/dev/null" "${CURRENT_LINK}"
    echo "Created current symlink placeholder at ${CURRENT_LINK}"
fi

# Create basic health check page
cat > "${HTTP_ROOT}/root/index.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>iPXE Boot Server</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; padding: 50px; }
        h1 { color: #333; }
        p { color: #666; }
    </style>
</head>
<body>
    <h1>iPXE Boot Server</h1>
    <p>Server is running and ready for PXE boot.</p>
    <p><a href="/health">Health Check</a></p>
</body>
</html>
EOF

echo "HTTP server directories setup complete"
ls -la "${HTTP_ROOT}"
echo ""
echo "Directory structure:"
find "${HTTP_ROOT}" -type f -o -type l | head -20
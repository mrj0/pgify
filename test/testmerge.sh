#!/bin/bash

. test/testcommon.sh

cat > "$input" <<EOF
INSERT INTO \`wp_options\` (\`option_name\`, \`option_value\`, \`autoload\`) VALUES ('_site_transient_timeout_theme_roots', '1290220365', 'yes') ON DUPLICATE KEY UPDATE \`option_name\` = VALUES(\`option_name\`), \`option_value\` = VALUES(\`option_value\`), \`autoload\` = VALUES(\`autoload\`)
EOF

cat > "$expected" <<EOF
EOF

pgify

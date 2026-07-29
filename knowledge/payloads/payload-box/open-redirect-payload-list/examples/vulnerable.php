<?php
/**
 * Vulnerable PHP Examples - Open Redirect
 * WARNING: These are intentionally vulnerable examples for educational purposes only!
 * DO NOT use this code in production environments.
 */

error_reporting(E_ALL);
ini_set('display_errors', 1);

?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Open Redirect Vulnerable Examples</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
            background-color: #f5f5f5;
        }
        .container {
            background: white;
            padding: 30px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            margin-bottom: 20px;
        }
        h1 {
            color: #d32f2f;
            border-bottom: 3px solid #d32f2f;
            padding-bottom: 10px;
        }
        h2 {
            color: #1976d2;
            margin-top: 30px;
        }
        .warning {
            background-color: #fff3cd;
            border: 2px solid #ffc107;
            border-radius: 4px;
            padding: 15px;
            margin: 20px 0;
        }
        .vulnerable {
            background-color: #ffebee;
            border-left: 4px solid #d32f2f;
            padding: 15px;
            margin: 15px 0;
        }
        code {
            background-color: #f5f5f5;
            padding: 2px 6px;
            border-radius: 3px;
            font-family: 'Courier New', monospace;
        }
        pre {
            background-color: #263238;
            color: #aed581;
            padding: 15px;
            border-radius: 4px;
            overflow-x: auto;
        }
        .example-link {
            display: inline-block;
            padding: 10px 15px;
            background-color: #1976d2;
            color: white;
            text-decoration: none;
            border-radius: 4px;
            margin: 5px;
        }
        .example-link:hover {
            background-color: #1565c0;
        }
        .info {
            background-color: #e3f2fd;
            border-left: 4px solid #2196f3;
            padding: 15px;
            margin: 15px 0;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>⚠️ Open Redirect Vulnerable Examples</h1>

        <div class="warning">
            <strong>⚠️ WARNING:</strong> This page contains intentionally vulnerable code for educational and testing purposes only.
            These vulnerabilities should NEVER be implemented in production environments.
        </div>

        <h2>What is Open Redirect?</h2>
        <p>
            An Open Redirect vulnerability occurs when a web application accepts user-controllable input
            that specifies a link to an external site and uses that link in a redirect without proper validation.
        </p>

        <div class="info">
            <strong>📚 Learning Purpose:</strong> Use these examples to understand how open redirect vulnerabilities work
            and test your payloads against them.
        </div>
    </div>

    <?php
    // Example 1: Basic Unvalidated Redirect
    if (isset($_GET['example']) && $_GET['example'] == '1') {
        echo '<div class="container">';
        echo '<h2>Example 1: Basic Unvalidated Redirect</h2>';
        echo '<div class="vulnerable">';
        echo '<strong>Vulnerability:</strong> No validation on redirect URL';
        echo '</div>';

        if (isset($_GET['url'])) {
            $redirect_url = $_GET['url'];
            echo '<p>Redirecting to: <code>' . htmlspecialchars($redirect_url) . '</code></p>';
            echo '<p>This redirect will execute in 2 seconds...</p>';
            header("Refresh: 2; URL=" . $redirect_url);
        } else {
            echo '<p>Test this vulnerability by adding <code>?example=1&url=//evil.com</code></p>';
        }
        echo '</div>';
    }

    // Example 2: Location Header Redirect
    if (isset($_GET['example']) && $_GET['example'] == '2') {
        if (isset($_GET['redirect'])) {
            $redirect_url = $_GET['redirect'];
            header("Location: " . $redirect_url);
            exit();
        }
    }

    // Example 3: Weak Domain Validation (Bypassable)
    if (isset($_GET['example']) && $_GET['example'] == '3') {
        echo '<div class="container">';
        echo '<h2>Example 3: Weak Domain Validation</h2>';
        echo '<div class="vulnerable">';
        echo '<strong>Vulnerability:</strong> Using substring check instead of proper validation';
        echo '</div>';

        if (isset($_GET['next'])) {
            $next_url = $_GET['next'];

            // Weak validation - can be bypassed with victim.com.evil.com
            if (strpos($next_url, 'victim.com') !== false) {
                echo '<p>Redirecting to: <code>' . htmlspecialchars($next_url) . '</code></p>';
                echo '<p>This redirect will execute in 2 seconds...</p>';
                header("Refresh: 2; URL=" . $next_url);
            } else {
                echo '<p>Invalid redirect URL</p>';
            }
        } else {
            echo '<p>Test with: <code>?example=3&next=https://victim.com.evil.com</code></p>';
            echo '<p>Or: <code>?example=3&next=https://victim.com@evil.com</code></p>';
        }
        echo '</div>';
    }

    // Example 4: JavaScript Redirect
    if (isset($_GET['example']) && $_GET['example'] == '4') {
        echo '<div class="container">';
        echo '<h2>Example 4: JavaScript Redirect</h2>';
        echo '<div class="vulnerable">';
        echo '<strong>Vulnerability:</strong> User input directly in JavaScript';
        echo '</div>';

        if (isset($_GET['returnTo'])) {
            $return_url = $_GET['returnTo'];
            echo '<script>';
            echo 'setTimeout(function() {';
            echo '    window.location = "' . $return_url . '";';
            echo '}, 2000);';
            echo '</script>';
            echo '<p>Redirecting to: <code>' . htmlspecialchars($return_url) . '</code></p>';
        } else {
            echo '<p>Test with: <code>?example=4&returnTo=//evil.com</code></p>';
        }
        echo '</div>';
    }

    // Example 5: Meta Refresh Redirect
    if (isset($_GET['example']) && $_GET['example'] == '5') {
        if (isset($_GET['destination'])) {
            $destination = $_GET['destination'];
            echo '<!DOCTYPE html>';
            echo '<html><head>';
            echo '<meta http-equiv="refresh" content="2;url=' . $destination . '">';
            echo '</head><body>';
            echo '<p>Redirecting to: ' . htmlspecialchars($destination) . '</p>';
            echo '</body></html>';
            exit();
        }
    }

    // Example 6: OAuth-like Redirect URI
    if (isset($_GET['example']) && $_GET['example'] == '6') {
        echo '<div class="container">';
        echo '<h2>Example 6: OAuth-like Redirect URI</h2>';
        echo '<div class="vulnerable">';
        echo '<strong>Vulnerability:</strong> Insufficient redirect_uri validation';
        echo '</div>';

        if (isset($_GET['redirect_uri']) && isset($_GET['client_id'])) {
            $redirect_uri = $_GET['redirect_uri'];
            $client_id = $_GET['client_id'];

            echo '<p>Simulating OAuth flow...</p>';
            echo '<p>Client ID: <code>' . htmlspecialchars($client_id) . '</code></p>';
            echo '<p>Redirect URI: <code>' . htmlspecialchars($redirect_uri) . '</code></p>';
            echo '<p>Redirecting in 2 seconds...</p>';
            header("Refresh: 2; URL=" . $redirect_uri);
        } else {
            echo '<p>Test with: <code>?example=6&client_id=123&redirect_uri=//evil.com</code></p>';
        }
        echo '</div>';
    }

    // Example 7: URL Parameter with Path Traversal
    if (isset($_GET['example']) && $_GET['example'] == '7') {
        echo '<div class="container">';
        echo '<h2>Example 7: Relative Path Redirect (Vulnerable)</h2>';
        echo '<div class="vulnerable">';
        echo '<strong>Vulnerability:</strong> Accepts // which becomes protocol-relative';
        echo '</div>';

        if (isset($_GET['continue'])) {
            $continue_url = $_GET['continue'];

            // Weak check - only blocks http:// and https://
            if (!preg_match('/^https?:\/\//i', $continue_url)) {
                echo '<p>Redirecting to: <code>' . htmlspecialchars($continue_url) . '</code></p>';
                echo '<p>This redirect will execute in 2 seconds...</p>';
                header("Refresh: 2; URL=" . $continue_url);
            } else {
                echo '<p>Absolute URLs not allowed</p>';
            }
        } else {
            echo '<p>Test with: <code>?example=7&continue=//evil.com</code></p>';
            echo '<p>Or: <code>?example=7&continue=///evil.com</code></p>';
        }
        echo '</div>';
    }
    ?>

    <?php if (!isset($_GET['example']) || !in_array($_GET['example'], ['1', '2', '3', '4', '5', '6', '7'])): ?>
    <div class="container">
        <h2>🧪 Available Test Examples</h2>

        <h3>1. Basic Unvalidated Redirect</h3>
        <p>No validation whatsoever on the redirect URL.</p>
        <a href="?example=1&url=//evil.com" class="example-link">Test Example 1</a>
        <pre>?example=1&url=//evil.com</pre>

        <h3>2. Location Header Redirect</h3>
        <p>Direct redirect using PHP header() function.</p>
        <a href="?example=2&redirect=https://google.com" class="example-link">Test Example 2</a>
        <pre>?example=2&redirect=https://google.com</pre>

        <h3>3. Weak Domain Validation</h3>
        <p>Uses simple string matching that can be bypassed.</p>
        <a href="?example=3&next=https://victim.com.evil.com" class="example-link">Test Example 3</a>
        <pre>?example=3&next=https://victim.com.evil.com
?example=3&next=https://victim.com@evil.com</pre>

        <h3>4. JavaScript Redirect</h3>
        <p>Client-side redirect using window.location.</p>
        <a href="?example=4&returnTo=//google.com" class="example-link">Test Example 4</a>
        <pre>?example=4&returnTo=//google.com</pre>

        <h3>5. Meta Refresh Redirect</h3>
        <p>HTML meta tag redirect.</p>
        <a href="?example=5&destination=https://google.com" class="example-link">Test Example 5</a>
        <pre>?example=5&destination=https://google.com</pre>

        <h3>6. OAuth-like Redirect URI</h3>
        <p>Simulates OAuth flow with vulnerable redirect_uri.</p>
        <a href="?example=6&client_id=123&redirect_uri=//evil.com" class="example-link">Test Example 6</a>
        <pre>?example=6&client_id=123&redirect_uri=//evil.com</pre>

        <h3>7. Relative Path Redirect</h3>
        <p>Blocks absolute URLs but allows protocol-relative URLs.</p>
        <a href="?example=7&continue=//google.com" class="example-link">Test Example 7</a>
        <pre>?example=7&continue=//google.com
?example=7&continue=///evil.com</pre>

        <h2>🛠️ Testing Tips</h2>
        <div class="info">
            <ul>
                <li>Replace <code>evil.com</code> or <code>google.com</code> with your own domain for testing</li>
                <li>Use Burp Suite Intruder to test multiple payloads automatically</li>
                <li>Check the Location header in response using browser developer tools</li>
                <li>Try various encoding techniques: URL encoding, double encoding, Unicode</li>
                <li>Test with protocol-relative URLs (//evil.com)</li>
                <li>Try bypassing with @ symbol (https://trusted.com@evil.com)</li>
            </ul>
        </div>

        <h2>🔒 Secure Implementation Example</h2>
        <pre><?php echo htmlspecialchars('<?php
// SECURE EXAMPLE - Use whitelist validation
$allowed_redirects = [
    \'/dashboard\',
    \'/profile\',
    \'/settings\'
];

if (isset($_GET[\'redirect\'])) {
    $redirect = $_GET[\'redirect\'];

    if (in_array($redirect, $allowed_redirects, true)) {
        header("Location: " . $redirect);
        exit();
    }
}

// Or validate domain properly
$redirect_url = $_GET[\'url\'];
$parsed = parse_url($redirect_url);

if ($parsed && isset($parsed[\'host\'])) {
    if ($parsed[\'host\'] === \'yourdomain.com\') {
        header("Location: " . $redirect_url);
        exit();
    }
}
?>'); ?></pre>
    </div>
    <?php endif; ?>

    <div class="container">
        <h2>📖 Additional Resources</h2>
        <ul>
            <li><a href="https://owasp.org/www-project-web-security-testing-guide/latest/4-Web_Application_Security_Testing/11-Client-side_Testing/04-Testing_for_Client-side_URL_Redirect">OWASP Testing Guide</a></li>
            <li><a href="https://cwe.mitre.org/data/definitions/601.html">CWE-601: URL Redirection to Untrusted Site</a></li>
            <li><a href="https://portswigger.net/kb/issues/00500100_open-redirection-reflected">PortSwigger: Open Redirection</a></li>
        </ul>
    </div>

    <div class="container" style="text-align: center; color: #666;">
        <p><small>⚠️ For educational purposes only. Use responsibly and ethically.</small></p>
    </div>
</body>
</html>

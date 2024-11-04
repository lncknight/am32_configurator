// sleep.js
console.log('Node.js process is running...');

// Function to keep the process alive
function keepAlive() {
    setTimeout(keepAlive, 1000); // Call itself every 1000 milliseconds (1 second)
}

keepAlive(); // Start the keep-alive function
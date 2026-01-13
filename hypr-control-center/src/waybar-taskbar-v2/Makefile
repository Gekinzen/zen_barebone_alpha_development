# ═══════════════════════════════════════════════════════════════════════════════
# Waybar Taskbar v2 - Nerd Font + Python Popup
# ═══════════════════════════════════════════════════════════════════════════════

CXX = g++
CXXFLAGS = -std=c++17 -Wall -Wextra -O2
LDFLAGS = $(shell pkg-config --libs gio-unix-2.0 glib-2.0 gtk4 gdk-pixbuf-2.0) -lpthread

PKG_CFLAGS = $(shell pkg-config --cflags gio-unix-2.0 glib-2.0 gtk4 gdk-pixbuf-2.0)

SRC = src/main.cpp src/taskbar.cpp src/hypr_ipc.cpp src/pinned_manager.cpp src/icon_resolver.cpp
OBJ = $(SRC:.cpp=.o)
TARGET = waybar-taskbar

.PHONY: all clean install

all: $(TARGET)

$(TARGET): $(OBJ)
	@echo "🔗 Linking $(TARGET)..."
	$(CXX) $(OBJ) -o $(TARGET) $(LDFLAGS)
	@echo "✅ Build complete!"

src/%.o: src/%.cpp
	@echo "📦 Compiling $<..."
	$(CXX) $(CXXFLAGS) $(PKG_CFLAGS) -c $< -o $@

clean:
	rm -f $(OBJ) $(TARGET)

install: $(TARGET)
	@echo "📁 Installing..."
	mkdir -p ~/.config/waybar/scripts
	cp $(TARGET) ~/.config/waybar/scripts/
	cp scripts/taskbar-popup.py ~/.config/waybar/scripts/
	chmod +x ~/.config/waybar/scripts/waybar-taskbar
	chmod +x ~/.config/waybar/scripts/taskbar-popup.py
	@echo "✅ Installed!"
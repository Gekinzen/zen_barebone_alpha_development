# ═══════════════════════════════════════════════════════════════════════════════
# Waybar Taskbar Module - Makefile
# ═══════════════════════════════════════════════════════════════════════════════

CXX = g++
CXXFLAGS = -std=c++17 -Wall -Wextra -O2 -fPIC
LDFLAGS = -shared

# Package configs
PKG_CFLAGS = $(shell pkg-config --cflags gtk4 glib-2.0 gio-2.0 gdk-pixbuf-2.0)
PKG_LIBS = $(shell pkg-config --libs gtk4 glib-2.0 gio-2.0 gdk-pixbuf-2.0)

# For standalone executable (Waybar custom module via exec)
EXEC_CFLAGS = $(shell pkg-config --cflags gio-unix-2.0 glib-2.0 gio-2.0 gdk-pixbuf-2.0 gtk4)
EXEC_LIBS = $(shell pkg-config --libs gio-unix-2.0 glib-2.0 gio-2.0 gdk-pixbuf-2.0 gtk4) -lpthread

# Sources
SRC_DIR = src
SOURCES = $(SRC_DIR)/main.cpp \
          $(SRC_DIR)/taskbar.cpp \
          $(SRC_DIR)/hypr_ipc.cpp \
          $(SRC_DIR)/pinned_manager.cpp \
          $(SRC_DIR)/icon_resolver.cpp

OBJECTS = $(SOURCES:.cpp=.o)
TARGET = waybar-taskbar

# ═══════════════════════════════════════════════════════════════════════════════
# TARGETS
# ═══════════════════════════════════════════════════════════════════════════════

.PHONY: all clean install test

all: $(TARGET)

$(TARGET): $(OBJECTS)
	@echo "🔗 Linking $(TARGET)..."
	$(CXX) $(OBJECTS) -o $(TARGET) $(EXEC_LIBS)
	@echo "✅ Build complete: $(TARGET)"

$(SRC_DIR)/%.o: $(SRC_DIR)/%.cpp
	@echo "📦 Compiling $<..."
	$(CXX) $(CXXFLAGS) $(EXEC_CFLAGS) -c $< -o $@

clean:
	@echo "🧹 Cleaning..."
	rm -f $(OBJECTS) $(TARGET)

install: $(TARGET)
	@echo "📁 Installing to ~/.config/waybar/scripts/"
	mkdir -p ~/.config/waybar/scripts
	cp $(TARGET) ~/.config/waybar/scripts/
	chmod +x ~/.config/waybar/scripts/$(TARGET)
	@echo "✅ Installed!"
	@echo ""
	@echo "Add to your Waybar config.jsonc:"
	@echo '  "custom/taskbar": {'
	@echo '      "exec": "~/.config/waybar/scripts/waybar-taskbar",'
	@echo '      "return-type": "json",'
	@echo '      "interval": 1,'
	@echo '      "on-click": "~/.config/waybar/scripts/waybar-taskbar click $$1"'
	@echo '  }'

test: $(TARGET)
	@echo "🧪 Running test..."
	./$(TARGET) --test

# ═══════════════════════════════════════════════════════════════════════════════
# DEPENDENCIES
# ═══════════════════════════════════════════════════════════════════════════════

deps:
	@echo "📦 Required packages (Arch Linux):"
	@echo "   sudo pacman -S base-devel gtk4 glib2 gdk-pixbuf2 nlohmann-json"
# Alternative Makefile for Wazuh Agent
# This provides a simpler build alternative to CMake

# Installation prefix
PREFIX ?= /var/ossec

# Build directories
SRCDIR = src
BUILDDIR = build
BINDIR = $(BUILDDIR)/bin
LIBDIR = $(BUILDDIR)/lib

# Compiler settings
CC = gcc
CXX = g++
CFLAGS = -Wall -Wextra -O2 -D_GNU_SOURCE
CXXFLAGS = -Wall -Wextra -O2 -std=c++20 -D_GNU_SOURCE
LDFLAGS = -lpthread -lssl -lcrypto -lz -lm

# Include directories
INCLUDES = -I$(SRCDIR) \
           -I$(SRCDIR)/headers \
           -I$(SRCDIR)/shared \
           -I$(SRCDIR)/shared_modules/common \
           -I$(SRCDIR)/shared_modules/utils \
           -I$(SRCDIR)/external/cJSON \
           -I$(SRCDIR)/external/openssl/include \
           -I$(SRCDIR)/external/zlib

# Source files for shared library
SHARED_SOURCES = $(wildcard $(SRCDIR)/shared/*.c) \
                 $(wildcard $(SRCDIR)/util/*.c) \
                 $(wildcard $(SRCDIR)/os_net/*.c) \
                 $(wildcard $(SRCDIR)/os_regex/*.c) \
                 $(wildcard $(SRCDIR)/os_xml/*.c) \
                 $(wildcard $(SRCDIR)/os_crypto/*.c) \
                 $(wildcard $(SRCDIR)/os_zlib/*.c)

SHARED_OBJECTS = $(SHARED_SOURCES:$(SRCDIR)/%.c=$(BUILDDIR)/%.o)

# Agent daemon sources
AGENTD_SOURCES = $(wildcard $(SRCDIR)/client-agent/*.c)
AGENTD_OBJECTS = $(AGENTD_SOURCES:$(SRCDIR)/%.c=$(BUILDDIR)/%.o)

# Log collector sources
LOGCOLLECTOR_SOURCES = $(wildcard $(SRCDIR)/logcollector/*.c)
LOGCOLLECTOR_OBJECTS = $(LOGCOLLECTOR_SOURCES:$(SRCDIR)/%.c=$(BUILDDIR)/%.o)

# Syscheck sources (simplified - full version needs complex build)
SYSCHECK_SOURCES = $(wildcard $(SRCDIR)/rootcheck/*.c)
SYSCHECK_OBJECTS = $(SYSCHECK_SOURCES:$(SRCDIR)/%.c=$(BUILDDIR)/%.o)

# Execd sources
EXECD_SOURCES = $(wildcard $(SRCDIR)/os_execd/*.c)
EXECD_OBJECTS = $(EXECD_SOURCES:$(SRCDIR)/%.c=$(BUILDDIR)/%.o)

# Targets
.PHONY: all clean install help

all: prepare shared agentd logcollector execd

help:
	@echo "Wazuh Agent Makefile"
	@echo ""
	@echo "Targets:"
	@echo "  all          Build all components"
	@echo "  shared       Build shared library"
	@echo "  agentd       Build agent daemon"
	@echo "  logcollector Build log collector"
	@echo "  execd        Build active response daemon"
	@echo "  clean        Clean build artifacts"
	@echo "  install      Install to PREFIX ($(PREFIX))"
	@echo "  help         Show this help"
	@echo ""
	@echo "Variables:"
	@echo "  PREFIX       Installation prefix (default: /var/ossec)"
	@echo "  CC           C compiler (default: gcc)"
	@echo "  CXX          C++ compiler (default: g++)"

prepare:
	@echo "Preparing build directories..."
	@mkdir -p $(BUILDDIR) $(BINDIR) $(LIBDIR)
	@mkdir -p $(BUILDDIR)/shared $(BUILDDIR)/util $(BUILDDIR)/os_net
	@mkdir -p $(BUILDDIR)/os_regex $(BUILDDIR)/os_xml $(BUILDDIR)/os_crypto $(BUILDDIR)/os_zlib
	@mkdir -p $(BUILDDIR)/client-agent $(BUILDDIR)/logcollector $(BUILDDIR)/rootcheck $(BUILDDIR)/os_execd

shared: $(LIBDIR)/libwazuhshared.a

$(LIBDIR)/libwazuhshared.a: $(SHARED_OBJECTS)
	@echo "Creating shared library..."
	@ar rcs $@ $^

agentd: $(BINDIR)/wazuh-agentd

$(BINDIR)/wazuh-agentd: $(AGENTD_OBJECTS) $(LIBDIR)/libwazuhshared.a
	@echo "Building wazuh-agentd..."
	@$(CC) -o $@ $(filter-out %main.o,$^) $(LDFLAGS)

logcollector: $(BINDIR)/wazuh-logcollector

$(BINDIR)/wazuh-logcollector: $(LOGCOLLECTOR_OBJECTS) $(LIBDIR)/libwazuhshared.a
	@echo "Building wazuh-logcollector..."
	@$(CC) -o $@ $(filter-out %main.o,$^) $(LDFLAGS)

execd: $(BINDIR)/wazuh-execd

$(BINDIR)/wazuh-execd: $(EXECD_OBJECTS) $(LIBDIR)/libwazuhshared.a
	@echo "Building wazuh-execd..."
	@$(CC) -o $@ $(filter-out %main.o,$^) $(LDFLAGS)

# Generic pattern rule for C files
$(BUILDDIR)/%.o: $(SRCDIR)/%.c
	@echo "Compiling $<..."
	@mkdir -p $(dir $@)
	@$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

clean:
	@echo "Cleaning build artifacts..."
	@rm -rf $(BUILDDIR)

install: all
	@echo "Installing Wazuh Agent to $(PREFIX)..."
	@mkdir -p $(PREFIX)/bin $(PREFIX)/etc $(PREFIX)/var/run $(PREFIX)/logs
	@cp $(BINDIR)/* $(PREFIX)/bin/ 2>/dev/null || true
	@cp -r etc/* $(PREFIX)/etc/ 2>/dev/null || true
	@cp -r ruleset $(PREFIX)/etc/ 2>/dev/null || true
	@cp -r scripts/* $(PREFIX)/bin/ 2>/dev/null || true
	@chmod +x $(PREFIX)/bin/*
	@echo "Installation completed."

# Show what will be built
show-sources:
	@echo "Shared library sources: $(words $(SHARED_SOURCES)) files"
	@echo "Agent daemon sources: $(words $(AGENTD_SOURCES)) files"  
	@echo "Log collector sources: $(words $(LOGCOLLECTOR_SOURCES)) files"
	@echo "Execd sources: $(words $(EXECD_SOURCES)) files"

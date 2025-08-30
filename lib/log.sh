#!/bin/bash

# Requires colors.sh to be sourced first

log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')] $1${NC}" >&2
}

success() {
    echo -e "${GREEN}✓ $1${NC}" >&2
}

error() {
    echo -e "${RED}✗ $1${NC}" >&2
}

warn() {
    echo -e "${YELLOW}⚠ $1${NC}" >&2
}

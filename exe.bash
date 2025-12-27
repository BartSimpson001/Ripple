#!/bin/bash

# Root lib folder
LIB_PATH="lib"

# Create common folders only if they don't exist
COMMON_PATH="$LIB_PATH/common"
if [ ! -d "$COMMON_PATH" ]; then
  echo "🔧 Creating common folders..."
  mkdir -p $COMMON_PATH/network        # For API clients, interceptors
  mkdir -p $COMMON_PATH/firebase       # For Firebase functions, Firestore logic
else
  echo "✅ Common folders already exist. Skipping creation."
fi

# Accept feature name as argument
FEATURE_NAME=$1

if [ -z "$FEATURE_NAME" ]; then
  echo "❌ Please provide a feature name. Example: ./setup.sh report"
  exit 1
fi

FEATURE_PATH="$LIB_PATH/features/$FEATURE_NAME"

echo "📁 Creating feature structure for '$FEATURE_NAME'..."

# Presentation layer only
mkdir -p $FEATURE_PATH/presentation/bloc
mkdir -p $FEATURE_PATH/presentation/pages
mkdir -p $FEATURE_PATH/presentation/widgets

# Create placeholder BLoC files
touch $FEATURE_PATH/presentation/bloc/${FEATURE_NAME}_bloc.dart
touch $FEATURE_PATH/presentation/bloc/${FEATURE_NAME}_event.dart
touch $FEATURE_PATH/presentation/bloc/${FEATURE_NAME}_state.dart

echo "✅ Feature '$FEATURE_NAME' structure created successfully in lib/"
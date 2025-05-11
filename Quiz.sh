#!/bin/bash

# Script to set up a basic quiz system
# This script creates directories and files for a Japanese quiz application

# Create main directories
mkdir -p japanese_quiz/{questions,answers,data}

# Create question categories
CATEGORIES=("grammar" "vocabulary" "reading" "logic" "math" "culture")

for category in "${CATEGORIES[@]}"; do
    mkdir -p japanese_quiz/questions/$category
    mkdir -p japanese_quiz/answers/$category
    echo "Created category: $category"
done

# Create initial config file
cat > japanese_quiz/config.sh << EOL
#!/bin/bash
# Configuration for Japanese Quiz Application

QUIZ_NAME="Japanese Proficiency Test Practice"
QUIZ_VERSION="1.0"
LANGUAGE="ja_JP"
MAX_QUESTIONS_PER_SESSION=10
RANDOMIZE_QUESTIONS=true
SHOW_CORRECT_ANSWERS=true
EOL

chmod +x japanese_quiz/config.sh
echo "Quiz setup complete!"

#!/bin/bash

# Define the ASCII art frames for a snow crystal
frame1=(
"                                            "
"                                            "
"                                            "
"                                            "
"                                            "
"                                            "
"                     *                      "
"                                            "
"                                            "
"                                            "
)

frame2=(
"                                            "
"                                            "
"                                            "
"                                            "
"                     *                      "
"                    * *                     "
"                     *                      "
"                                            "
"                                            "
"                                            "
)

frame3=(
"                                            "
"                                            "
"                                            "
"                     *                      "
"                    * *                     "
"                   *   *                    "
"                    * *                     "
"                     *                      "
"                                            "
"                                            "
)

frame4=(
"                                            "
"                                            "
"                     *                      "
"                    * *                     "
"                   *   *                    "
"                  *     *                   "
"                   *   *                    "
"                    * *                     "
"                     *                      "
"                                            "
)

frame5=(
"                                            "
"                     *                      "
"                    * *                     "
"                   *   *                    "
"                  *     *                   "
"                 *       *                  "
"                  *     *                   "
"                   *   *                    "
"                    * *                     "
"                     *                      "
)

frame6=(
"                     *                      "
"                    * *                     "
"                   *   *                    "
"                  *     *                   "
"                 *       *                  "
"                *         *                 "
"                 *       *                  "
"                  *     *                   "
"                   *   *                    "
"                    * *                     "
)

# Function to display the animation
display_animation() {
    for frame in "${frames[@]}"; do
        clear
        for line in "${frame[@]}"; do
            echo "$line"
        done
        sleep 0.5
    done
}

# Main loop
while true; do
    frames=(
        "${frame1[@]}"
        "${frame2[@]}"
        "${frame3[@]}"
        "${frame4[@]}"
        "${frame5[@]}"
        "${frame6[@]}"
    )
    display_animation
done

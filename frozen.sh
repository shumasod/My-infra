#!/bin/bash

# Define the ASCII art frames for a Frozen-themed animation
frame1=(
"                                            "
"                                            "
"                     *                      "
"                    * *                     "
"                   *   *                    "
"                    * *                     "
"                     *                      "
"                                            "
"                                            "
"                                            "
)

frame2=(
"                     *                      "
"                   *   *                    "
"                  *  *  *                   "
"                 *   *   *                  "
"                *  *   *  *                 "
"                 *   *   *                  "
"                  *  *  *                   "
"                   *   *                    "
"                     *                      "
"                                            "
)

frame3=(
"                   *     *                  "
"                 *    *    *                "
"               *   *     *   *              "
"                *    * *    *               "
"             *      * * *      *            "
"                *    * *    *               "
"               *   *     *   *              "
"                 *    *    *                "
"                   *     *                  "
"                                            "
)

frame4=(
"                 *         *                "
"               *    * *    *                "
"             *   *       *   *              "
"           *    *  *   *  *    *            "
"         *      *    *    *      *          "
"           *    *  *   *  *    *            "
"             *   *       *   *              "
"               *    * *    *                "
"                 *         *                "
"                                            "
)

frame5=(
"               *             *              "
"             *    *     *    *              "
"           *   *           *   *            "
"         *    *  *       *  *    *          "
"       *      *    *   *    *      *        "
"         *    *  *       *  *    *          "
"           *   *           *   *            "
"             *    *     *    *              "
"               *             *              "
"                                            "
)

# Function to display the animation
display_animation() {
    for frame in "${frames[@]}"; do
        clear
        echo "     ❄️  Frozen Magic ❄️"
        for line in "${frame[@]}"; do
            echo -e "\033[34m$line\033[0m"  # Blue color
        done
        echo "  Let It Go🎵, Let It Go!🎵 ✨"
        sleep 0.7
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
    )
    display_animation
done

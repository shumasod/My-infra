#!/usr/bin/awk -f

BEGIN {
    srand()
    balance = 100
    bet = 10
    symbols = "🍒🍋🍊🍇🔔💎"
    split(symbols, sym, "")

    print "Welcome to AWK Slot Game!"
    print "Your initial balance is $" balance
    print "Enter to spin (bet $" bet "), 'q' to quit"

    while (1) {
        printf "Balance: $%d. Press Enter to spin or 'q' to quit: ", balance
        getline input < "/dev/stdin"
        
        if (input == "q") {
            print "Thanks for playing! Your final balance: $" balance
            exit
        }

        if (balance < bet) {
            print "Not enough balance to play. Game over!"
            exit
        }

        balance -= bet
        s1 = sym[int(rand() * 6) + 1]
        s2 = sym[int(rand() * 6) + 1]
        s3 = sym[int(rand() * 6) + 1]
        
        print "[ " s1 " | " s2 " | " s3 " ]"
        
        if (s1 == s2 && s2 == s3) {
            winnings = bet * 10
            balance += winnings
            print "Jackpot! You won $" winnings "!"
        } else if (s1 == s2 || s2 == s3 || s1 == s3) {
            winnings = bet * 2
            balance += winnings
            print "Two of a kind! You won $" winnings "!"
        } else {
            print "No match. Better luck next time!"
        }
    }
}
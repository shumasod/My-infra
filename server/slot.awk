#!/usr/bin/awk -f

BEGIN {
    srand()
    balance = 1000
    minBet = 10
    maxBet = 100
    symbols = "🍒🍋🍊🍇🔔💎7️⃣"
    split(symbols, sym, "")
    payTable["🍒🍒🍒"] = 50
    payTable["🍋🍋🍋"] = 75
    payTable["🍊🍊🍊"] = 100
    payTable["🍇🍇🍇"] = 125
    payTable["🔔🔔🔔"] = 150
    payTable["💎💎💎"] = 200
    payTable["7️⃣7️⃣7️⃣"] = 500

    print "Welcome to AWK Casino Slot Machine!"
    print "Your initial balance is $" balance
    print "Minimum bet: $" minBet ", Maximum bet: $" maxBet
    printPayTable()

    while (1) {
        printf "Balance: $%d. Enter bet amount (or 'q' to quit): ", balance
        getline input < "/dev/stdin"
        
        if (input == "q") {
            print "Thanks for playing! Your final balance: $" balance
            exit
        }

        bet = int(input)
        if (bet < minBet || bet > maxBet) {
            print "Invalid bet. Please bet between $" minBet " and $" maxBet
            continue
        }

        if (balance < bet) {
            print "Not enough balance to place this bet."
            continue
        }

        balance -= bet
        s1 = sym[int(rand() * 8) + 1]
        s2 = sym[int(rand() * 8) + 1]
        s3 = sym[int(rand() * 8) + 1]
        
        print "\n[ " s1 " | " s2 " | " s3 " ]"
        
        combination = s1 s2 s3
        if (combination in payTable) {
            multiplier = payTable[combination]
            winnings = bet * multiplier
            balance += winnings
            print "Congratulations! You won $" winnings "!"
            print "Multiplier: x" multiplier
        } else if (s1 == s2 || s2 == s3 || s1 == s3) {
            winnings = bet * 2
            balance += winnings
            print "Two of a kind! You won $" winnings "!"
        } else {
            print "No match. Better luck next time!"
        }
        print "Current balance: $" balance "\n"
    }
}

function printPayTable() {
    print "\nPay Table:"
    print "🍒🍒🍒 - x50"
    print "🍋🍋🍋 - x75"
    print "🍊🍊🍊 - x100"
    print "🍇🍇🍇 - x125"
    print "🔔🔔🔔 - x150"
    print "💎💎💎 - x200"
    print "7️⃣7️⃣7️⃣ - x500"
    print "Any two matching symbols - x2\n"
}
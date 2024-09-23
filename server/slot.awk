#!/usr/bin/awk -f

BEGIN {
    srand()
    balance = 1000
    minBet = 10
    maxBet = 100
    symbols = "🍒🍋🍊🍇🔔💎7️⃣"
    split(symbols, sym, "")
    
    # Adjusted payout table
    payTable["🍒🍒🍒"] = 40
    payTable["🍋🍋🍋"] = 60
    payTable["🍊🍊🍊"] = 80
    payTable["🍇🍇🍇"] = 100
    payTable["🔔🔔🔔"] = 150
    payTable["💎💎💎"] = 250
    payTable["7️⃣7️⃣7️⃣"] = 500
    
    # Symbol weights (higher number = higher probability)
    weights["🍒"] = 30
    weights["🍋"] = 25
    weights["🍊"] = 20
    weights["🍇"] = 15
    weights["🔔"] = 10
    weights["💎"] = 5
    weights["7️⃣"] = 2
    
    totalWeight = 0
    for (s in weights) {
        totalWeight += weights[s]
    }
    
    print "Welcome to AWK Casino Slot Machine!"
    print "Your initial balance is $" balance
    print "Minimum bet: $" minBet ", Maximum bet: $" maxBet
    printPayTable()
    
    while (1) {
        printf "Balance: $%d. Enter bet amount (or 'q' to quit): ", balance
        if ((getline input < "/dev/stdin") <= 0) {
            print "Error reading input. Exiting."
            exit 1
        }
        
        if (input == "q") {
            print "Thanks for playing! Your final balance: $" balance
            exit 0
        }
        
        if (input ~ /^[0-9]+$/) {
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
            s1 = spinReel()
            s2 = spinReel()
            s3 = spinReel()
            
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
        } else {
            print "Invalid input. Please enter a number or 'q' to quit."
        }
    }
}

function spinReel() {
    r = int(rand() * totalWeight)
    for (s in weights) {
        r -= weights[s]
        if (r < 0) return s
    }
    return sym[1]  # Fallback to first symbol (should never happen)
}

function printPayTable() {
    print "\nPay Table:"
    print "🍒🍒🍒 - x40"
    print "🍋🍋🍋 - x60"
    print "🍊🍊🍊 - x80"
    print "🍇🍇🍇 - x100"
    print "🔔🔔🔔 - x150"
    print "💎💎💎 - x250"
    print "7️⃣7️⃣7️⃣ - x500"
    print "Any two matching symbols - x2\n"
}

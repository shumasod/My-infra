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
    
<<<<<<< HEAD
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
=======
    print "\n\033[1;33m🎰 Welcome to the Grand AWK Casino! 🎰\033[0m"
    print "═════════════════════════════════════════"
    print "Your starting chips: \033[1;32m$" balance "\033[0m"
    print "Minimum bet: \033[1;36m$" minBet "\033[0m, Maximum bet: \033[1;36m$" maxBet "\033[0m"
    printPayTable()
    
    while (1) {
        printf "\n\033[1;34mYour chips: $%d\033[0m. Place your bet (or 'cash out'): ", balance
        if ((getline input < "/dev/stdin") <= 0) {
            print "\033[1;31mError reading input. Cashing out.\033[0m"
            exit 1
        }
        
        if (input == "cash out") {
            print "\n\033[1;33m💰 Cashing out...\033[0m"
            print "Thank you for playing at the Grand AWK Casino!"
            printf "You're leaving with \033[1;32m$%d\033[0m in chips.\n", balance
            exit 0
        }
        
        if (input ~ /^[0-9]+$/) {
            bet = int(input)
            if (bet < minBet || bet > maxBet) {
                print "\033[1;31mInvalid bet. Please bet between $" minBet " and $" maxBet "\033[0m"
>>>>>>> e814cf3647480b6c980e29a7a3a1c5a5054720f3
                continue
            }
            
            if (balance < bet) {
<<<<<<< HEAD
                print "Not enough balance to place this bet."
=======
                print "\033[1;31mNot enough chips for this bet.\033[0m"
>>>>>>> e814cf3647480b6c980e29a7a3a1c5a5054720f3
                continue
            }
            
            balance -= bet
<<<<<<< HEAD
            s1 = spinReel()
            s2 = spinReel()
            s3 = spinReel()
            
            print "\n[ " s1 " | " s2 " | " s3 " ]"
=======
            print "\n\033[1;35m🎰 Spinning the reels... 🎰\033[0m"
            system("sleep 1")
            s1 = spinReel()
            system("sleep 0.5")
            s2 = spinReel()
            system("sleep 0.5")
            s3 = spinReel()
            
            print "\n\033[1;33m╔═════╦═════╦═════╗"
            printf "║  %s  ║  %s  ║  %s  ║\n", s1, s2, s3
            print "╚═════╩═════╩═════╝\033[0m"
>>>>>>> e814cf3647480b6c980e29a7a3a1c5a5054720f3
            
            combination = s1 s2 s3
            if (combination in payTable) {
                multiplier = payTable[combination]
                winnings = bet * multiplier
                balance += winnings
<<<<<<< HEAD
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
=======
                print "\n\033[1;32m🎉 JACKPOT! 🎉\033[0m"
                print "You won \033[1;32m$" winnings "\033[0m!"
                print "Multiplier: \033[1;33mx" multiplier "\033[0m"
            } else if (s1 == s2 || s2 == s3 || s1 == s3) {
                winnings = bet * 2
                balance += winnings
                print "\n\033[1;32m🎊 Two of a kind! 🎊\033[0m"
                print "You won \033[1;32m$" winnings "\033[0m!"
            } else {
                print "\n\033[1;31m😞 No match. Better luck next time!\033[0m"
            }
            print "\nCurrent chips: \033[1;34m$" balance "\033[0m"
        } else {
            print "\033[1;31mInvalid input. Please enter a number or 'cash out'.\033[0m"
>>>>>>> e814cf3647480b6c980e29a7a3a1c5a5054720f3
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
<<<<<<< HEAD
    print "\nPay Table:"
    print "🍒🍒🍒 - x40"
    print "🍋🍋🍋 - x60"
    print "🍊🍊🍊 - x80"
    print "🍇🍇🍇 - x100"
    print "🔔🔔🔔 - x150"
    print "💎💎💎 - x250"
    print "7️⃣7️⃣7️⃣ - x500"
    print "Any two matching symbols - x2\n"
=======
    print "\n\033[1;36m💰 Payout Table 💰\033[0m"
    print "═══════════════════"
    print "🍒🍒🍒 - \033[1;33mx40\033[0m"
    print "🍋🍋🍋 - \033[1;33mx60\033[0m"
    print "🍊🍊🍊 - \033[1;33mx80\033[0m"
    print "🍇🍇🍇 - \033[1;33mx100\033[0m"
    print "🔔🔔🔔 - \033[1;33mx150\033[0m"
    print "💎💎💎 - \033[1;33mx250\033[0m"
    print "7️⃣7️⃣7️⃣ - \033[1;33mx500\033[0m"
    print "Any two matching symbols - \033[1;33mx2\033[0m"
    print "═══════════════════"
>>>>>>> e814cf3647480b6c980e29a7a3a1c5a5054720f3
}
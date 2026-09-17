import Foundation

/// A bank of 50 positive morning affirmations used for the daily affirmation
/// notification. The user can also set their own custom affirmation instead.
enum Affirmations {
    static let all: [String] = [
        "Today is full of possibility, and so are you.",
        "You have everything you need to make today good.",
        "One calm breath at a time, you've got this.",
        "Your potential today is limitless.",
        "You are stronger than any challenge in front of you.",
        "Small steps forward are still steps forward.",
        "You deserve a morning that feels like yours.",
        "Your focus is your superpower today.",
        "You are exactly where you need to be.",
        "Progress, not perfection, is the goal today.",
        "You bring something to this world no one else can.",
        "Today, you choose calm over rush.",
        "You are capable of amazing things.",
        "Your effort today plants tomorrow's results.",
        "Be proud of how far you've already come.",
        "You are allowed to take up space and shine.",
        "Today you lead your day, not the other way around.",
        "Your mind is clear, your purpose is strong.",
        "You can do hard things, gently.",
        "Every morning is a fresh start, and this is yours.",
        "You are worthy of rest and worthy of effort.",
        "Confidence looks good on you today.",
        "You handle what comes with grace and grit.",
        "Today you water the seeds of who you're becoming.",
        "Your presence matters more than your productivity.",
        "You are grounded, focused, and ready.",
        "Choose the thoughts that lift you up today.",
        "You have the power to make today meaningful.",
        "Trust yourself; you've made it through every day so far.",
        "Today is a good day to be kind to yourself.",
        "You are building a life you're proud of, one morning at a time.",
        "Your calm is your strength.",
        "You are enough, exactly as you are right now.",
        "Let today be light, focused, and full of intention.",
        "You move toward your goals with steady purpose.",
        "Your morning sets the tone, and you set the morning.",
        "You are resilient, resourceful, and ready for today.",
        "Give your best, and let that be enough.",
        "Today you choose growth over comfort.",
        "You carry a quiet strength wherever you go.",
        "Your future self is grateful for what you do today.",
        "You deserve good things, and you're working toward them.",
        "Breathe in focus, breathe out doubt.",
        "You are the calm in your own storm.",
        "Today, your energy goes where it matters most.",
        "You are becoming the person you want to be.",
        "Make today count in small, kind ways.",
        "You are open to the good things coming your way.",
        "Steady and strong, that's how you start today.",
        "This is your morning, and it's going to be a good one."
    ]

    static func forToday() -> String {
        let day = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        return all[(day - 1) % all.count]
    }

    static func random() -> String { all.randomElement() ?? all[0] }
}

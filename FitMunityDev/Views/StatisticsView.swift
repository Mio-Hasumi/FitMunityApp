//
//  StatisticsView.swift
//  FitMunityDev
//
//  Created by Haoran Jisun on 3/18/25.
//


import SwiftUI

struct StatisticsView: View {
    @ObservedObject private var calorieManager = CalorieManager.shared
    @State private var currentDate = Date()
    @State private var isActivityLogExpanded = false
    
    private let dailyGoal = 2000 // Default daily goal
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header title
                Text("Statistics")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top)
                
                // Show loading indicator when loading data
                if calorieManager.isLoading {
                    VStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(1.5)
                            .padding()
                        
                        Text("Loading activity data...")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else if let error = calorieManager.error {
                    // Show error message if there was an error
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundColor(.orange)
                            .padding()
                        
                        Text("Failed to load activity data")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.black)
                            .padding(.bottom, 4)
                        
                        Text("Please try again later")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                        
                        Button(action: {
                            // Retry loading
                            Task {
                                do {
                                    try await calorieManager.fetchEntriesFromSupabase()
                                } catch {
                                    print("Failed to reload: \(error)")
                                }
                            }
                        }) {
                            Text("Retry")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                                .background(Color.blue)
                                .cornerRadius(8)
                        }
                        .padding(.top)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    // Summary card (calories gained vs. burned)
                    VStack(spacing: 16) {
                        // Calorie number
                        Text("\(calorieManager.netCalories()) cal")
                            .font(.system(size: 32, weight: .bold))
                        
                        // Date and activities
                        HStack(spacing: 16) {
                            // Let declaration moved outside of the View hierarchy
                            Text(getFormattedDate(from: currentDate, format: "MMMM d"))
                                .font(.system(size: 16))
                                .foregroundColor(.black)
                            
                            HStack(spacing: 4) {
                                Text("\(calorieManager.activityCount())")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.black)
                                
                                Text("Activities")
                                    .font(.system(size: 16))
                                    .foregroundColor(Color.black.opacity(0.6))
                            }
                        }
                        
                        // Replace the single graph with two separate graphs
                        // 1. Daily timeline graph
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Daily Activity Timeline")
                                .font(.system(size: 16, weight: .semibold))
                                .padding(.horizontal)
                            
                            TimelineCalorieGraph(entries: calorieManager.entries)
                                .frame(height: 180)
                                .padding(.horizontal)
                        }
                        
                        // 2. Weekly summary graph
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Last 7 Days Summary")
                                .font(.system(size: 16, weight: .semibold))
                                .padding(.horizontal)
                            
                            WeeklyCalorieGraph(entries: calorieManager.entries)
                                .frame(height: 180)
                                .padding(.horizontal)
                        }
                        
                        // Legend
                        HStack(spacing: 20) {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 8, height: 8)
                                
                                Text("Gained")
                                    .font(.system(size: 14))
                            }
                            
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 8, height: 8)
                                
                                Text("Burnt")
                                    .font(.system(size: 14))
                            }
                        }
                    }
                    .padding(20)
                    .background(Color(hex: "FFF4D0"))
                    .cornerRadius(20)
                    .padding(.horizontal)
                    
                    // Activity log title and toggle
                    HStack {
                        Text("Activity Log")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        Button(action: {
                            withAnimation(.spring()) {
                                isActivityLogExpanded.toggle()
                            }
                        }) {
                            HStack(spacing: 4) {
                                Text(isActivityLogExpanded ? "Collapse" : "Expand")
                                    .font(.system(size: 14))
                                    .foregroundColor(.black)
                                
                                Image(systemName: isActivityLogExpanded ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.black)
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(Color(hex: "FFDD66").opacity(0.5))
                            .cornerRadius(12)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top)
                    
                    // Calorie entries list
                    if calorieManager.entries.isEmpty {
                        Text("No activities recorded yet")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                            .padding()
                    } else {
                        let sortedEntries = calorieManager.entries.sorted(by: { $0.date > $1.date }) // Sort by newest first
                        
                        VStack(spacing: 0) {
                            // Show only the most recent 3 logs when collapsed, or all entries when expanded
                            if isActivityLogExpanded {
                                ScrollView {
                                    VStack(spacing: 0) {
                                        ForEach(sortedEntries) { entry in
                                            CalorieEntryRow(entry: entry)
                                        }
                                    }
                                    .padding(.bottom, 10)
                                }
                                .frame(maxHeight: 300)
                                .background(Color.white.opacity(0.3))
                                .cornerRadius(10)
                                .padding(.horizontal)
                            } else {
                                // Show only the first 3 when collapsed
                                ForEach(Array(sortedEntries.prefix(3))) { entry in
                                    CalorieEntryRow(entry: entry)
                                }
                            }
                        }
                    }
                }
                
                Spacer(minLength: 40)
            }
            .background(Color(hex: "FFF8E1"))
        }
        .onAppear {
            // Update current date when view appears
            currentDate = Date()
            
            // Fetch calorie entries from Supabase
            Task {
                do {
                    try await calorieManager.fetchEntriesFromSupabase()
                } catch {
                    print("Failed to fetch calorie entries: \(error)")
                }
            }
        }
    }
    
    // Helper method to format dates
    private func getFormattedDate(from date: Date, format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
}

// Row to display a single calorie entry
struct CalorieEntryRow: View {
    let entry: CalorieEntry
    @ObservedObject private var calorieManager = CalorieManager.shared
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        HStack(spacing: 15) {
            // Icon
            ZStack {
                Circle()
                    .fill(entry.isGained ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Image(systemName: entry.isGained ? "fork.knife" : "figure.run")
                    .font(.system(size: 18))
                    .foregroundColor(entry.isGained ? .green : .red)
            }
            
            // Description and timestamp
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.description)
                    .font(.system(size: 16))
                    .lineLimit(1)
                
                Text(formattedDate(entry.date))
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Calorie count
            Text(entry.isGained ? "+\(entry.calories)" : "-\(entry.calories)")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(entry.isGained ? .green : .red)
                + Text(" cal")
                .font(.system(size: 14))
                .foregroundColor(.gray)
            
            // Delete button
            Button(action: {
                showDeleteConfirmation = true
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 16))
                    .foregroundColor(.red.opacity(0.7))
                    .padding(8)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 20)
        .background(Color.white)
        .cornerRadius(10)
        .padding(.horizontal)
        .padding(.vertical, 5)
        .alert(isPresented: $showDeleteConfirmation) {
            Alert(
                title: Text("Delete Activity"),
                message: Text("Are you sure you want to delete this activity entry?"),
                primaryButton: .destructive(Text("Delete")) {
                    calorieManager.deleteEntry(id: entry.id)
                },
                secondaryButton: .cancel()
            )
        }
    }
    
    // Format the date for display
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// Timeline graph for displaying individual calorie entries over time
struct TimelineCalorieGraph: View {
    let entries: [CalorieEntry]
    
    // Move calculations to computed properties
    private var sortedEntries: [CalorieEntry] {
        entries.sorted(by: { $0.date < $1.date })
    }
    
    private var cumulativeEntries: [(entry: CalorieEntry, cumulative: Int)] {
        var result: [(entry: CalorieEntry, cumulative: Int)] = []
        var runningTotal = 0
        
        for entry in sortedEntries {
            if entry.isGained {
                runningTotal += entry.calories
            } else {
                runningTotal -= entry.calories
            }
            result.append((entry, runningTotal))
        }
        
        return result
    }
    
    private var maxAbsValue: Int {
        max(500, cumulativeEntries.map { abs($0.cumulative) }.max() ?? 500)
    }
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            
            Group {
                // Use empty view for no entries
                if entries.isEmpty {
                    ZStack {
                        Color.white.opacity(0.5)
                            .cornerRadius(10)
                        
                        Text("No data available")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                } else {
                    ZStack(alignment: .topLeading) {
                        // Background
                        Color.white.opacity(0.5)
                            .cornerRadius(10)
                        
                        // Main content group - inset to leave room for axes
                        ZStack {
                            // Grid lines
                            VStack(spacing: 0) {
                                ForEach(0..<5) { i in
                                    Divider()
                                        .background(Color.gray.opacity(0.3))
                                        .frame(height: i == 2 ? 1.5 : 0.5) // Middle line is heavier
                                    
                                    if i < 4 {
                                        Spacer()
                                    }
                                }
                            }
                            
                            // Horizontal zero line (thicker)
                            Rectangle()
                                .fill(Color.black.opacity(0.3))
                                .frame(width: width - 60, height: 1.5)
                                .position(x: (width - 60) / 2 + 50, y: height / 2)
                            
                            // Data visualization
                            HStack(spacing: 0) {
                                // Y-axis labels
                                VStack {
                                    Text("+\(maxAbsValue)")
                                        .font(.system(size: 10))
                                        .foregroundColor(.gray)
                                    
                                    Spacer()
                                    
                                    Text("0")
                                        .font(.system(size: 10))
                                        .foregroundColor(.gray)
                                    
                                    Spacer()
                                    
                                    Text("-\(maxAbsValue)")
                                        .font(.system(size: 10))
                                        .foregroundColor(.gray)
                                }
                                .frame(width: 40, height: height - 30)
                                
                                // Chart area
                                ZStack {
                                    // Draw the line connecting points
                                    drawCumulativeLine(entries: cumulativeEntries, maxValue: maxAbsValue, width: width - 60, height: height - 30)
                                    
                                    // Draw points for each cumulative total
                                    drawCumulativePoints(entries: cumulativeEntries, maxValue: maxAbsValue, width: width - 60, height: height - 30)
                                }
                                .frame(width: width - 60, height: height - 30)
                            }
                            
                            // X-axis time labels at bottom
                            VStack {
                                Spacer()
                                
                                // Date labels
                                dateLabels(entries: sortedEntries, width: width - 50, height: 20)
                                    .padding(.leading, 50)
                                    .frame(height: 30)
                            }
                        }
                        .padding(.bottom, 10)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func drawCumulativeLine(entries: [(entry: CalorieEntry, cumulative: Int)], maxValue: Int, width: CGFloat, height: CGFloat) -> some View {
        if entries.isEmpty {
            EmptyView()
        } else {
            ZStack {
                // Line path for the connecting line between points
                Path { path in
                    // Start point
                    let firstX = CGFloat(0)
                    let firstY = height / 2 - (height / 2) * (CGFloat(entries[0].cumulative) / CGFloat(maxValue))
                    path.move(to: CGPoint(x: firstX, y: firstY))
                    
                    // Connect all points
                    for (index, data) in entries.enumerated() {
                        let x = width * CGFloat(index) / max(CGFloat(entries.count - 1), 1.0)
                        let y = height / 2 - (height / 2) * (CGFloat(data.cumulative) / CGFloat(maxValue))
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                .stroke(Color.blue, lineWidth: 2)
                
                // Area fill below the line
                Path { path in
                    // Start at bottom left
                    path.move(to: CGPoint(x: CGFloat(0), y: height / 2))
                    
                    // Go to the first data point
                    let firstY = height / 2 - (height / 2) * (CGFloat(entries[0].cumulative) / CGFloat(maxValue))
                    path.addLine(to: CGPoint(x: CGFloat(0), y: firstY))
                    
                    // Connect all points along the top
                    for (index, data) in entries.enumerated() {
                        let x = width * CGFloat(index) / max(CGFloat(entries.count - 1), 1.0)
                        let y = height / 2 - (height / 2) * (CGFloat(data.cumulative) / CGFloat(maxValue))
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                    
                    // Go to bottom right and close the path
                    path.addLine(to: CGPoint(x: width, y: height / 2))
                    path.addLine(to: CGPoint(x: CGFloat(0), y: height / 2))
                }
                .fill(Color.blue.opacity(0.1))
            }
        }
    }
    
    @ViewBuilder
    private func drawCumulativePoints(entries: [(entry: CalorieEntry, cumulative: Int)], maxValue: Int, width: CGFloat, height: CGFloat) -> some View {
        ForEach(Array(entries.enumerated()), id: \.1.entry.id) { index, data in
            let x = width * CGFloat(index) / max(CGFloat(entries.count - 1), 1.0)
            let y = height / 2 - (height / 2) * (CGFloat(data.cumulative) / CGFloat(maxValue))
            
            // Draw point with color based on whether it's above or below zero
            Circle()
                .fill(data.cumulative >= 0 ? Color.green : Color.red)
                .frame(width: 8, height: 8)
                .position(x: x, y: y)
            
            // Optional: add a vertical line down to the zero axis for clarity
            Group {
                if abs(y - height / 2) > 4 { // Only draw if the point is not too close to zero
                    Path { path in
                        path.move(to: CGPoint(x: CGFloat(x), y: CGFloat(y)))
                        path.addLine(to: CGPoint(x: CGFloat(x), y: height / 2))
                    }
                    .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
                }
            }
        }
    }
    
    @ViewBuilder
    private func dateLabels(entries: [CalorieEntry], width: CGFloat, height: CGFloat) -> some View {
        // Show at most 3 date labels for clarity
        let labelCount = min(entries.count, 3)
        let step = max(1, entries.count / labelCount)
        
        HStack(spacing: 0) {
            ForEach(0..<labelCount, id: \.self) { i in
                let index = i * step
                Group {
                    if index < entries.count {
                        let dateString = formatTimestamp(entries[index].date)
                        
                        Text(dateString)
                            .font(.system(size: 8))
                            .foregroundColor(.gray)
                            .frame(width: width / CGFloat(labelCount))
                    }
                }
            }
        }
    }
    
    // Helper for date formatting
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
    }
}

// Weekly summary graph for showing daily totals over the last 7 days
struct WeeklyCalorieGraph: View {
    let entries: [CalorieEntry]
    
    // Calculate daily totals for the last 7 days
    var dailyTotals: [(date: Date, net: Int, gained: Int, burned: Int)] {
        let calendar = Calendar.current
        let now = Date()
        
        // Create array of the last 7 days
        let last7Days = (0..<7).map { dayOffset -> Date in
            let components = DateComponents(day: -dayOffset)
            return calendar.date(byAdding: components, to: now) ?? now
        }.reversed()
        
        // Initialize totals for each day
        var result: [(date: Date, net: Int, gained: Int, burned: Int)] = last7Days.map { date in
            let startOfDay = calendar.startOfDay(for: date)
            return (date: startOfDay, net: 0, gained: 0, burned: 0)
        }
        
        // Calculate totals for each day
        for entry in entries {
            // Get start of the entry date
            let entryDay = calendar.startOfDay(for: entry.date)
            
            // Find matching day in our result array
            if let index = result.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: entryDay) }) {
                // Update totals based on entry type
                if entry.isGained {
                    result[index].gained += entry.calories
                    result[index].net += entry.calories
                } else {
                    result[index].burned += entry.calories
                    result[index].net -= entry.calories
                }
            }
        }
        
        return result
    }
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            
            ZStack(alignment: .topLeading) {
                // Background
                Color.white.opacity(0.5)
                    .cornerRadius(10)
                
                VStack(spacing: 0) {
                    // Main chart area with bars
                    HStack(spacing: 0) {
                        // Y-axis labels
                        VStack {
                            Text("+500")
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                            
                            Spacer()
                            
                            Text("0")
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                            
                            Spacer()
                            
                            Text("-500")
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                        }
                        .frame(width: 40, height: height - 30)
                        
                        // Bar chart
                        ZStack {
                            // Background grid
                            VStack(spacing: 0) {
                                ForEach(0..<5) { i in
                                    Divider()
                                        .background(Color.gray.opacity(0.3))
                                        .frame(height: i == 2 ? 1.5 : 0.5) // Middle line is heavier
                                    
                                    if i < 4 {
                                        Spacer()
                                    }
                                }
                            }
                            
                            // Horizontal zero line (thicker)
                            Rectangle()
                                .fill(Color.black.opacity(0.3))
                                .frame(width: width - 40, height: 1.5)
                                .position(x: (width - 40) / 2, y: height / 2 - 15)
                            
                            // Net calorie bars - single bar per day showing net value
                            HStack(spacing: 0) {
                                ForEach(0..<dailyTotals.count, id: \.self) { index in
                                    let dayData = dailyTotals[index]
                                    let cellWidth = (width - 40) / CGFloat(dailyTotals.count)
                                    let barWidth = cellWidth * 0.6
                                    let maxValue = 500.0 // Scale to 500 calories
                                    
                                    DayBarView(
                                        dayData: dayData,
                                        cellWidth: cellWidth,
                                        barWidth: barWidth,
                                        maxValue: maxValue,
                                        height: height
                                    )
                                }
                            }
                        }
                        .frame(width: width - 40, height: height - 30)
                    }
                    
                    // X-axis date labels
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: 40, height: 30)
                        
                        HStack(spacing: 0) {
                            ForEach(0..<dailyTotals.count, id: \.self) { index in
                                let cellWidth = (width - 40) / CGFloat(dailyTotals.count)
                                let dateString = formatDayLabel(dailyTotals[index].date)
                                
                                Text(dateString)
                                    .font(.system(size: 8))
                                    .foregroundColor(.gray)
                                    .frame(width: cellWidth)
                            }
                        }
                    }
                    .frame(height: 30)
                }
            }
            .cornerRadius(10)
        }
    }
    
    // Helper method for date formatting
    private func formatDayLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: date)
    }
}

// By refactoring daily bars into a separate view
struct DayBarView: View {
    let dayData: (date: Date, net: Int, gained: Int, burned: Int)
    let cellWidth: CGFloat
    let barWidth: CGFloat
    let maxValue: CGFloat
    let height: CGFloat
    
    var body: some View {
        Group {
            // Only draw if we have non-zero net calories
            if dayData.net != 0 {
                // Single bar showing net calorie value
                let normalizedNet = min(max(CGFloat(dayData.net) / maxValue, -1.0), 1.0)
                let barHeight = abs(normalizedNet) * (height - 30) / 2
                
                if dayData.net > 0 {
                    // Positive bar (extends upward from center)
                    VStack {
                        Spacer().frame(height: (height - 30) / 2 - barHeight)
                        Rectangle()
                            .fill(Color.green.opacity(0.7))
                            .frame(width: barWidth, height: barHeight)
                        Spacer().frame(height: (height - 30) / 2)
                    }
                    .frame(width: cellWidth)
                } else {
                    // Negative bar (extends downward from center)
                    VStack {
                        Spacer().frame(height: (height - 30) / 2)
                        Rectangle()
                            .fill(Color.red.opacity(0.7))
                            .frame(width: barWidth, height: barHeight)
                        Spacer().frame(height: (height - 30) / 2 - barHeight)
                    }
                    .frame(width: cellWidth)
                }
            } else {
                // Empty spacer for days with no net calories
                Spacer()
                    .frame(width: cellWidth)
            }
        }
    }
}

struct StatisticsView_Previews: PreviewProvider {
    static var previews: some View {
        StatisticsView()
    }
}

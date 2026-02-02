package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"
)

type UsageData struct {
	FiveHour *UsagePeriod `json:"five_hour"`
	SevenDay *UsagePeriod `json:"seven_day"`
}

type UsagePeriod struct {
	Utilization float64 `json:"utilization"`
	ResetsAt    string  `json:"resets_at"`
}

const configDir = ".config/menubar-utils"

func main() {
	// Get config from ~/.config/menubar-utils/
	homeDir, err := os.UserHomeDir()
	if err != nil {
		printError("C: ERR | color=red", "Cannot determine home directory")
		return
	}

	envFile := filepath.Join(homeDir, configDir, "claude-usage.env")

	// Load .env file
	env, err := loadEnv(envFile)
	if err != nil {
		configDirPath := filepath.Join(homeDir, configDir)
		printError("C: CFG | color=red",
			"Cannot read config file",
			"Expected: "+envFile,
			"---",
			"Create config dir | bash=mkdir param1=-p param2="+configDirPath+" terminal=false",
			"Open config dir | bash=open param1="+configDirPath+" terminal=false")
		return
	}

	orgID := env["CLAUDE_ORG_ID"]
	sessionKey := env["CLAUDE_SESSION_KEY"]

	if orgID == "" || sessionKey == "" {
		printError("C: CFG | color=red", "Missing CLAUDE_ORG_ID or CLAUDE_SESSION_KEY", "Edit config | bash=open param1="+envFile+" terminal=false")
		return
	}

	// Fetch usage data
	data, status := fetchUsage(orgID, sessionKey)

	switch status {
	case "network_error":
		printError("C: --/-- | color=gray", "Network error")
		return
	case "auth_error":
		fmt.Println("C: AUTH | color=red")
		fmt.Println("---")
		fmt.Println("Session expired - refresh cookie")
		fmt.Println("---")
		fmt.Println("1. Open claude.ai in browser")
		fmt.Println("2. DevTools > Application > Cookies")
		fmt.Println("3. Copy sessionKey value")
		fmt.Println("---")
		fmt.Println("Edit config | bash=open param1=" + envFile + " terminal=false")
		return
	case "unavailable":
		fmt.Println("C: N/A | color=gray")
		fmt.Println("---")
		fmt.Println("Usage data unavailable")
		fmt.Println("Anthropic API returning nulls")
		fmt.Println("---")
		fmt.Println("Refresh | refresh=true")
		return
	}

	// Extract usage percentages
	var sessionPct, weeklyPct float64
	var sessionReset, weeklyReset string

	if data.FiveHour != nil {
		sessionPct = data.FiveHour.Utilization
		sessionReset = data.FiveHour.ResetsAt
	}
	if data.SevenDay != nil {
		weeklyPct = data.SevenDay.Utilization
		weeklyReset = data.SevenDay.ResetsAt
	}

	// Determine color based on max usage
	maxPct := sessionPct
	if weeklyPct > maxPct {
		maxPct = weeklyPct
	}
	color := getColor(maxPct)
	colorStr := ""
	if color != "" {
		colorStr = " | color=" + color
	}

	// Output SwiftBar format
	fmt.Printf("C: %.0f%%/%.0f%%%s\n", sessionPct, weeklyPct, colorStr)
	fmt.Println("---")
	fmt.Printf("Session: %.0f%% (resets in %s)\n", sessionPct, formatTimeUntil(sessionReset))
	fmt.Printf("Weekly: %.0f%% (resets in %s)\n", weeklyPct, formatTimeUntil(weeklyReset))
	fmt.Println("---")
	fmt.Println("Refresh | refresh=true")
	fmt.Println("Edit config | bash=open param1=" + envFile + " terminal=false")
}

func loadEnv(filename string) (map[string]string, error) {
	env := make(map[string]string)

	file, err := os.Open(filename)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		parts := strings.SplitN(line, "=", 2)
		if len(parts) == 2 {
			key := strings.TrimSpace(parts[0])
			value := strings.TrimSpace(parts[1])
			env[key] = value
		}
	}

	return env, scanner.Err()
}

func fetchUsage(orgID, sessionKey string) (*UsageData, string) {
	url := fmt.Sprintf("https://claude.ai/api/organizations/%s/usage", orgID)

	client := &http.Client{Timeout: 10 * time.Second}

	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return nil, "network_error"
	}

	req.Header.Set("Cookie", "sessionKey="+sessionKey)
	req.Header.Set("User-Agent", "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36")
	req.Header.Set("Accept", "application/json")

	resp, err := client.Do(req)
	if err != nil {
		return nil, "network_error"
	}
	defer resp.Body.Close()

	if resp.StatusCode == 401 || resp.StatusCode == 403 {
		return nil, "auth_error"
	}

	var data UsageData
	if err := json.NewDecoder(resp.Body).Decode(&data); err != nil {
		return nil, "unavailable"
	}

	if data.FiveHour == nil && data.SevenDay == nil {
		return nil, "unavailable"
	}

	return &data, "ok"
}

func formatTimeUntil(isoTimestamp string) string {
	if isoTimestamp == "" {
		return "unknown"
	}

	resetTime, err := time.Parse(time.RFC3339, isoTimestamp)
	if err != nil {
		return "unknown"
	}

	delta := time.Until(resetTime)
	if delta <= 0 {
		return "now"
	}

	totalHours := delta.Hours()
	if totalHours < 24 {
		hours := int(totalHours)
		minutes := int(delta.Minutes()) % 60
		return fmt.Sprintf("%dh %dm", hours, minutes)
	}

	days := int(totalHours / 24)
	hours := int(totalHours) % 24
	return fmt.Sprintf("%dd %dh", days, hours)
}

func getColor(pct float64) string {
	if pct >= 95 {
		return "red"
	}
	if pct >= 80 {
		return "orange"
	}
	return ""
}

func printError(header string, lines ...string) {
	fmt.Println(header)
	fmt.Println("---")
	for _, line := range lines {
		fmt.Println(line)
	}
}

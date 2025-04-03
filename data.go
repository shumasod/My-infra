package main

import (
	"bufio"
	"encoding/csv"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"runtime"
	"strconv"
	"sync"
	"time"
)

// DataPoint は1つのデータポイントを表す構造体
type DataPoint struct {
	ID     int
	Value  float64
	Label  string
	Time   time.Time
}

// AnalysisResult は分析結果を表す構造体
type AnalysisResult struct {
	Count       int
	Sum         float64
	Average     float64
	Min         float64
	Max         float64
	Labels      map[string]int
	TimeRange   time.Duration
}

// DataAnalyzer はデータ分析を行う構造体
type DataAnalyzer struct {
	workers int
	mu      sync.Mutex
	result  AnalysisResult
}

// NewDataAnalyzer は新しいDataAnalyzerインスタンスを作成
func NewDataAnalyzer(workers int) *DataAnalyzer {
	if workers <= 0 {
		workers = runtime.NumCPU()
	}
	return &DataAnalyzer{
		workers: workers,
		result: AnalysisResult{
			Labels: make(map[string]int),
			Min:    float64(^uint(0) >> 1), // MaxFloat64
			Max:    -float64(^uint(0) >> 1), // MinFloat64
		},
	}
}

// processChunk はデータチャンクを処理
func (da *DataAnalyzer) processChunk(chunk []DataPoint) {
	localResult := AnalysisResult{
		Labels: make(map[string]int),
		Min:    float64(^uint(0) >> 1),
		Max:    -float64(^uint(0) >> 1),
	}

	for _, dp := range chunk {
		localResult.Count++
		localResult.Sum += dp.Value
		localResult.Labels[dp.Label]++

		if dp.Value < localResult.Min {
			localResult.Min = dp.Value
		}
		if dp.Value > localResult.Max {
			localResult.Max = dp.Value
		}
	}

	da.mu.Lock()
	da.mergeResults(&localResult)
	da.mu.Unlock()
}

// mergeResults は局所的な結果をグローバルな結果にマージ
func (da *DataAnalyzer) mergeResults(local *AnalysisResult) {
	da.result.Count += local.Count
	da.result.Sum += local.Sum
	
	if local.Min < da.result.Min {
		da.result.Min = local.Min
	}
	if local.Max > da.result.Max {
		da.result.Max = local.Max
	}

	for label, count := range local.Labels {
		da.result.Labels[label] += count
	}
}

// AnalyzeFile はCSVファイルを分析
func (da *DataAnalyzer) AnalyzeFile(filepath string, chunkSize int) error {
	file, err := os.Open(filepath)
	if err != nil {
		return fmt.Errorf("failed to open file: %v", err)
	}
	defer file.Close()

	reader := csv.NewReader(bufio.NewReader(file))
	header, err := reader.Read()
	if err != nil {
		return fmt.Errorf("failed to read header: %v", err)
	}

	// データを読み込んでチャンクに分割
	var chunks [][]DataPoint
	currentChunk := make([]DataPoint, 0, chunkSize)
	
	for {
		record, err := reader.Read()
		if err != nil {
			break
		}

		dp, err := parseRecord(record)
		if err != nil {
			log.Printf("Warning: failed to parse record: %v", err)
			continue
		}

		currentChunk = append(currentChunk, dp)
		if len(currentChunk) >= chunkSize {
			chunks = append(chunks, currentChunk)
			currentChunk = make([]DataPoint, 0, chunkSize)
		}
	}

	if len(currentChunk) > 0 {
		chunks = append(chunks, currentChunk)
	}

	// 並行処理でチャンクを分析
	var wg sync.WaitGroup
	semaphore := make(chan struct{}, da.workers)

	for _, chunk := range chunks {
		wg.Add(1)
		semaphore <- struct{}{} // セマフォ獲得

		go func(chunk []DataPoint) {
			defer func() {
				<-semaphore // セマフォ解放
				wg.Done()
			}()
			da.processChunk(chunk)
		}(chunk)
	}

	wg.Wait()

	// 平均値を計算
	if da.result.Count > 0 {
		da.result.Average = da.result.Sum / float64(da.result.Count)
	}

	return nil
}

// parseRecord はCSVレコードをDataPointに変換
func parseRecord(record []string) (DataPoint, error) {
	id, err := strconv.Atoi(record[0])
	if err != nil {
		return DataPoint{}, fmt.Errorf("invalid ID: %v", err)
	}

	value, err := strconv.ParseFloat(record[1], 64)
	if err != nil {
		return DataPoint{}, fmt.Errorf("invalid value: %v", err)
	}

	timestamp, err := time.Parse(time.RFC3339, record[3])
	if err != nil {
		return DataPoint{}, fmt.Errorf("invalid timestamp: %v", err)
	}

	return DataPoint{
		ID:     id,
		Value:  value,
		Label:  record[2],
		Time:   timestamp,
	}, nil
}

// PrintResults は分析結果を表示
func (da *DataAnalyzer) PrintResults() {
	fmt.Println("\n=== Analysis Results ===")
	fmt.Printf("Total Records: %d\n", da.result.Count)
	fmt.Printf("Average Value: %.2f\n", da.result.Average)
	fmt.Printf("Min Value: %.2f\n", da.result.Min)
	fmt.Printf("Max Value: %.2f\n", da.result.Max)
	
	fmt.Println("\nLabel Distribution:")
	for label, count := range da.result.Labels {
		fmt.Printf("  %s: %d\n", label, count)
	}
}

func main() {
	// コマンドライン引数からファイルパスを取得
	if len(os.Args) < 2 {
		log.Fatal("Please provide the data file path")
	}
	dataFile := os.Args[1]

	// 分析の実行
	startTime := time.Now()
	
	analyzer := NewDataAnalyzer(runtime.NumCPU())
	err := analyzer.AnalyzeFile(dataFile, 1000) // チャンクサイズは1000
	if err != nil {
		log.Fatalf("Analysis failed: %v", err)
	}

	// 結果の表示
	analyzer.PrintResults()
	
	fmt.Printf("\nAnalysis completed in: %v\n", time.Since(startTime))
}
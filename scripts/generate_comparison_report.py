#!/usr/bin/env python3

import json
import sys
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Any

def parse_k6_summary(summary_path: Path) -> Dict[str, Any]:
    """K6 summary JSON 파싱"""
    with open(summary_path, 'r') as f:
        content = f.read()
        # K6 출력은 여러 JSON 객체를 포함할 수 있음, 마지막 것 사용
        lines = content.strip().split('\n')
        for line in reversed(lines):
            try:
                data = json.loads(line)
                if 'metrics' in data:
                    return data
            except json.JSONDecodeError:
                continue
    raise ValueError(f"No valid K6 summary found in {summary_path}")

def extract_metrics(data: Dict[str, Any]) -> Dict[str, float]:
    """주요 메트릭 추출"""
    metrics = data.get('metrics', {})

    http_req_duration = metrics.get('http_req_duration', {})
    http_reqs = metrics.get('http_reqs', {})
    http_req_failed = metrics.get('http_req_failed', {})

    return {
        'p50': http_req_duration.get('values', {}).get('p(50)', 0),
        'p95': http_req_duration.get('values', {}).get('p(95)', 0),
        'p99': http_req_duration.get('values', {}).get('p(99)', 0),
        'avg': http_req_duration.get('values', {}).get('avg', 0),
        'min': http_req_duration.get('values', {}).get('min', 0),
        'max': http_req_duration.get('values', {}).get('max', 0),
        'rps': http_reqs.get('values', {}).get('rate', 0),
        'total_requests': http_reqs.get('values', {}).get('count', 0),
        'error_rate': http_req_failed.get('values', {}).get('rate', 0) * 100,  # %
    }

def generate_comparison_table(results: Dict[str, Dict[str, float]]) -> str:
    """Markdown 비교 테이블 생성"""
    table = "| Adapter | P50 (ms) | P95 (ms) | P99 (ms) | Avg (ms) | RPS | Total Reqs | Error Rate |\n"
    table += "|---------|----------|----------|----------|----------|-----|------------|------------|\n"

    # P95 기준으로 정렬 (낮을수록 좋음)
    sorted_results = sorted(results.items(), key=lambda x: x[1]['p95'])

    for adapter, metrics in sorted_results:
        table += f"| {adapter:20} | {metrics['p50']:8.2f} | {metrics['p95']:8.2f} | {metrics['p99']:8.2f} | "
        table += f"{metrics['avg']:8.2f} | {metrics['rps']:7.2f} | {int(metrics['total_requests']):10} | "
        table += f"{metrics['error_rate']:6.2f}% |\n"

    return table

def generate_winner_analysis(results: Dict[str, Dict[str, float]]) -> str:
    """승자 분석"""
    analysis = "## 성능 분석\n\n"

    # P95 기준 최고 성능
    best_p95 = min(results.items(), key=lambda x: x[1]['p95'])
    analysis += f"### Latency Winner (P95 기준)\n"
    analysis += f"**{best_p95[0]}**: {best_p95[1]['p95']:.2f}ms\n\n"

    # RPS 기준 최고 성능
    best_rps = max(results.items(), key=lambda x: x[1]['rps'])
    analysis += f"### Throughput Winner (RPS 기준)\n"
    analysis += f"**{best_rps[0]}**: {best_rps[1]['rps']:.2f} req/s\n\n"

    # 에러율
    analysis += f"### Error Rates\n"
    for adapter, metrics in sorted(results.items()):
        analysis += f"- **{adapter}**: {metrics['error_rate']:.2f}%\n"

    analysis += "\n"

    return analysis

def generate_detailed_metrics(results: Dict[str, Dict[str, float]]) -> str:
    """상세 메트릭"""
    details = "## 상세 메트릭\n\n"

    for adapter, metrics in sorted(results.items()):
        details += f"### {adapter}\n\n"
        details += f"- **P50**: {metrics['p50']:.2f}ms\n"
        details += f"- **P95**: {metrics['p95']:.2f}ms\n"
        details += f"- **P99**: {metrics['p99']:.2f}ms\n"
        details += f"- **Average**: {metrics['avg']:.2f}ms\n"
        details += f"- **Min**: {metrics['min']:.2f}ms\n"
        details += f"- **Max**: {metrics['max']:.2f}ms\n"
        details += f"- **RPS**: {metrics['rps']:.2f} req/s\n"
        details += f"- **Total Requests**: {int(metrics['total_requests']):,}\n"
        details += f"- **Error Rate**: {metrics['error_rate']:.2f}%\n\n"

    return details

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 generate_comparison_report.py <report_directory>")
        sys.exit(1)

    report_dir = Path(sys.argv[1])

    if not report_dir.exists():
        print(f"Error: Directory {report_dir} does not exist")
        sys.exit(1)

    # summary.json 파일 찾기
    summary_files = list(report_dir.glob("*-summary.json"))

    if not summary_files:
        print(f"Error: No summary JSON files found in {report_dir}")
        sys.exit(1)

    print(f"Found {len(summary_files)} summary files")

    # 각 어댑터별 결과 파싱
    results = {}
    for summary_file in summary_files:
        # 파일명에서 어댑터 이름 추출 (예: spring_vt-20240101_120000-summary.json)
        adapter_name = summary_file.stem.split('-')[0]

        try:
            data = parse_k6_summary(summary_file)
            metrics = extract_metrics(data)
            results[adapter_name] = metrics
            print(f"✓ Parsed {adapter_name}")
        except Exception as e:
            print(f"✗ Failed to parse {summary_file}: {e}")

    if not results:
        print("Error: No valid results parsed")
        sys.exit(1)

    # Markdown 리포트 생성
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    output_file = report_dir / f"COMPARISON-{timestamp}.md"

    with open(output_file, 'w') as f:
        f.write(f"# DB Performance Comparison Report\n\n")
        f.write(f"**Generated**: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n")
        f.write(f"**Test Scenario**: 10M Orders JOIN Query (1 CPU, 1GB RAM per service)\n\n")

        f.write("---\n\n")
        f.write("## 비교 테이블\n\n")
        f.write(generate_comparison_table(results))
        f.write("\n")

        f.write("---\n\n")
        f.write(generate_winner_analysis(results))

        f.write("---\n\n")
        f.write(generate_detailed_metrics(results))

        f.write("---\n\n")
        f.write("## 테스트 환경\n\n")
        f.write("- **PostgreSQL**: 2 CPU, 2GB RAM\n")
        f.write("- **Spring Apps**: 1 CPU, 1GB RAM (각각)\n")
        f.write("- **Data**: 10M orders, 1M customers, 10K products\n")
        f.write("- **Query**: 3-way JOIN with status filter and pagination\n")
        f.write("- **K6 Load**: 20 VUs, 2 minutes steady state\n")

    print(f"\n✓ Report generated: {output_file}")
    print(f"\nView report:")
    print(f"  cat {output_file}")

if __name__ == "__main__":
    main()

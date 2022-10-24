#!/usr/bin/env python3

import argparse
import functools
import math
import matplotlib.pyplot as plt
import os
import re
import subprocess
import sys

"""A script to parse an XCUITest console log, extract raw benchmark values, and statistically analyze the SDK profiler's CPU overhead."""

def extract_values(line):
    """Given a log line with benchmark values, return a list of integer results it contains."""
    return re.search('.*\[Sentry Benchmark\] \[(.*)\] (\d*),(\d*),(\d*),(\d*)', line)

def overhead(results):
    """Given a set of results for system and user time from profiler and app, compute the profiler's overhead."""
    return 100.0 * (int(results[0]) + int(results[1])) / (int(results[2]) + int(results[3]))

def generate_report(benchmark, results, device_class, device_name):
    """Generate the report graph and text content for a single benchmark."""
    percentages = [f'{y:.3f}' for y in sorted([overhead(x) for x in results])]
    percentage_values = [y for y in sorted([overhead(x) for x in results])]

    print(f'{percentages=}')
    count = len(percentages)

    middle_index = int(math.floor(count / 2))
    print(f'{middle_index=}')
    median = (float(percentages[middle_index - 1]) + float(percentages[middle_index])) / 2 if count % 2 == 0 else percentages[middle_index]

    mean = functools.reduce(lambda res, next: res + float(next), percentages, 0) / len(percentages)

    p0 = percentages[0]
    p0_value = percentage_values[0]

    p90_index = math.ceil(len(percentages) * 0.9)
    p90 = percentages[p90_index - 1]
    p90_value = percentage_values[p90_index - 1]

    p99_index = math.ceil(len(percentages) * 0.99)
    p99 = percentages[p99_index - 1]
    p99_value = percentage_values[p99_index - 1]

    p99_9_index = math.ceil(len(percentages) * 0.999)
    p99_9 = percentages[p99_9_index - 1]
    p99_9_value = percentage_values[p99_9_index - 1]

    p99_999_index = math.ceil(len(percentages) * 0.99999)
    p99_999 = percentages[p99_999_index - 1]
    p99_999_value = percentage_values[p99_999_index - 1]

    p99_99999_index = math.ceil(len(percentages) * 0.9999999)
    p99_99999 = percentages[p99_99999_index - 1]
    p99_99999_value = percentage_values[p99_99999_index - 1]

    percentiles = [p0_value, p90_value, p99_value, p99_9_value, p99_999_value, p99_99999_value]
    plt.title(f'{benchmark} CPU time increase')
    plt.plot(percentiles, marker='o')
    plt.ylabel('Cpu time increase %')
    plt.xlabel('Percentile')
    plt.xticks(ticks=[0, 1, 2, 3, 4, 5], labels=['0%', '90%', '99%', '99.9%', '99.999%', '99.99999%'])
    plt.grid(True)
    benchmark_slug = benchmark.lower().replace(' ', '-')
    filename = f'ios_benchmarks_{device_class}_{device_name}_{benchmark_slug}.png'
    plt.savefig(f'benchmarks/{filename}')
    plt.clf()

    report = f'''
    <tr>
        <td>
            <img src="{filename}" />
        </td>
        <td>
            All observations (overhead, %):<br />
            {percentages}<br /><br />
            Median: {median}<br />
            Mean: {mean}<br />
            P0: {p0}<br />
            P90: {p90}<br />
            P99: {p99}<br />
            P99.9: {p99_9}<br />
            P99.999: {p99_999}<br />
            P99.99999: {p99_99999}
        </td>
    </tr>
'''
    return report

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('log_file_path', help='Path to the log file to parse.')
    parser.add_argument('device_class', help='The class of device the benchmarks were run on.')
    parser.add_argument('device_name', help='The name of the actual device the benchmarks were run on.')
    args = parser.parse_args()

    with open(args.log_file_path, 'r') as log_file:
        results = [extract_values(x) for x in log_file.read().splitlines() if 'Sentry Benchmark' in x]

    os.makedirs('benchmarks', exist_ok=True)

    results_per_benchmark = {}
    for result in results:
        benchmark = result.groups()[0]
        benchmark_result = result.groups()[1:]
        if benchmark not in results_per_benchmark:
            results_per_benchmark[benchmark] = [benchmark_result]
        else:
            results_per_benchmark[benchmark].append(benchmark_result)

    report = '<table width=100% padding=20>'

    for benchmark in results_per_benchmark:
        report += f'''
    <tr>
        <th colspan=2 style="background-color:#eee">
            {benchmark} running on {args.device_class} ({args.device_name})
        <th>
    </tr>
        '''
        next_row = generate_report(benchmark, results_per_benchmark[benchmark], args.device_class, args.device_name)
        report += next_row

    report += '</table>'

    with open(f'benchmarks/report_{args.device_class}_{args.device_name}.html', 'w') as report_file:
        report_file.write(report)

if __name__ == '__main__':
    main()

import Foundation
import OSLog

struct ClaudeCodeProvider: UsageProvider {
    let id: ProviderID = .claudeCode
    let displayName: String = "Claude Code"

    private static let logger = Logger(subsystem: "com.amitkumar.burnrate", category: "ClaudeCodeProvider")

    func fetchSnapshot() async -> UsageSnapshot {
        let script = Self.usageScript
        let hookURL = AppSupportPath.hookStatusJSON

        // Read hook file AND run Python script inside one detached task
        // so nothing crosses the actor boundary.
        let (scriptData, rawHookData): (Data, Data) = await Task.detached {
            let hookData = (try? Data(contentsOf: hookURL)) ?? Data()

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
            process.arguments = ["-c", script]
            let outPipe = Pipe()
            process.standardOutput = outPipe
            process.standardError = Pipe()
            guard (try? process.run()) != nil else { return (Data(), hookData) }
            process.waitUntilExit()
            return (outPipe.fileHandleForReading.readDataToEndOfFile(), hookData)
        }.value

        let hook = rawHookData.isEmpty ? nil : (try? JSONDecoder().decode(HookData.self, from: rawHookData))
        return Self.merge(scriptData: scriptData, hook: hook, hookURL: hookURL)
    }

    // MARK: - Merge hook + JSONL script data

    private static func merge(scriptData: Data, hook: HookData?, hookURL: URL) -> UsageSnapshot {
        // Determine staleness from hook file modification date
        let hookAge: TimeInterval
        if let attrs = try? FileManager.default.attributesOfItem(atPath: hookURL.path),
           let modified = attrs[.modificationDate] as? Date {
            hookAge = Date().timeIntervalSince(modified)
        } else {
            hookAge = .infinity
        }

        let dataSource: DataSource
        if hook != nil && hookAge < 5 * 60 {
            dataSource = .live
        } else if hook != nil && hookAge < 30 * 60 {
            dataSource = .stale
        } else {
            dataSource = .estimated
        }

        // Parse JSONL costs (always use these — they're accurate)
        var sessionCostUsd: Double? = nil
        var weeklyCostUsd: Double? = nil
        var fallbackModel: String? = nil
        var fallbackContextPct: Double? = nil
        var fallbackSessionPct: Double? = nil
        var fallbackSessionResetsAt: Date? = nil

        if !scriptData.isEmpty,
           let raw = try? JSONDecoder().decode(RawOutput.self, from: scriptData) {
            sessionCostUsd = raw.activeSession?.costUsd
            weeklyCostUsd  = raw.weekly?.costUsd
            fallbackModel  = raw.activeSession?.model
            fallbackContextPct = raw.activeSession?.contextPct
            fallbackSessionPct = raw.activeSession?.session5hPct.map { Double($0) }
            if let mins = raw.activeSession?.sessionResetMins {
                fallbackSessionResetsAt = Date().addingTimeInterval(Double(mins) * 60)
            }
        }

        // Prefer hook data for rate limits, model, context
        if let hook = hook {
            let sessionResetsAt = hook.rateLimits?.fiveHour?.resetsAt
                .map { Date(timeIntervalSince1970: $0) }
            let weeklyResetsAt = hook.rateLimits?.sevenDay?.resetsAt
                .map { Date(timeIntervalSince1970: $0) }

            logger.info("""
                Hook merged: session=\(hook.rateLimits?.fiveHour?.usedPercentage ?? -1, privacy: .public)% \
                weekly=\(hook.rateLimits?.sevenDay?.usedPercentage ?? -1, privacy: .public)% \
                ctx=\(hook.contextWindow?.usedPercentage ?? -1, privacy: .public)%
                """)

            return UsageSnapshot(
                providerId: .claudeCode,
                capturedAt: Date(),
                sessionUsedPercent: hook.rateLimits?.fiveHour?.usedPercentage ?? fallbackSessionPct,
                sessionResetsAt: sessionResetsAt ?? fallbackSessionResetsAt,
                weeklyUsedPercent: hook.rateLimits?.sevenDay?.usedPercentage,
                weeklyResetsAt: weeklyResetsAt,
                modelDisplayName: hook.model?.displayName ?? fallbackModel,
                contextUsedPercent: hook.contextWindow?.usedPercentage ?? fallbackContextPct,
                sessionCostUsd: sessionCostUsd,
                weeklyCostUsd: weeklyCostUsd,
                dataSource: dataSource,
                isHealthy: true,
                errorMessage: nil
            )
        }

        // No hook — JSONL fallback only
        guard sessionCostUsd != nil || fallbackModel != nil else {
            return makeUnhealthy("No sessions found in ~/.claude/projects")
        }

        return UsageSnapshot(
            providerId: .claudeCode,
            capturedAt: Date(),
            sessionUsedPercent: fallbackSessionPct,
            sessionResetsAt: fallbackSessionResetsAt,
            weeklyUsedPercent: nil,
            weeklyResetsAt: nil,
            modelDisplayName: fallbackModel,
            contextUsedPercent: fallbackContextPct,
            sessionCostUsd: sessionCostUsd,
            weeklyCostUsd: weeklyCostUsd,
            dataSource: .estimated,
            isHealthy: true,
            errorMessage: nil
        )
    }

    private static func makeUnhealthy(_ message: String) -> UsageSnapshot {
        UsageSnapshot(
            providerId: .claudeCode,
            capturedAt: Date(),
            sessionUsedPercent: nil,
            sessionResetsAt: nil,
            weeklyUsedPercent: nil,
            weeklyResetsAt: nil,
            modelDisplayName: nil,
            contextUsedPercent: nil,
            sessionCostUsd: nil,
            weeklyCostUsd: nil,
            dataSource: .estimated,
            isHealthy: false,
            errorMessage: message
        )
    }

    // MARK: - Hook JSON schema

    private struct HookData: Decodable {
        let model: HookModel?
        let contextWindow: HookContextWindow?
        let rateLimits: HookRateLimits?
        enum CodingKeys: String, CodingKey {
            case model
            case contextWindow = "context_window"
            case rateLimits = "rate_limits"
        }
    }

    private struct HookModel: Decodable {
        let displayName: String?
        enum CodingKeys: String, CodingKey {
            case displayName = "display_name"
        }
    }

    private struct HookContextWindow: Decodable {
        let usedPercentage: Double?
        enum CodingKeys: String, CodingKey {
            case usedPercentage = "used_percentage"
        }
    }

    private struct HookRateLimits: Decodable {
        let fiveHour: HookRateLimit?
        let sevenDay: HookRateLimit?
        enum CodingKeys: String, CodingKey {
            case fiveHour = "five_hour"
            case sevenDay = "seven_day"
        }
    }

    private struct HookRateLimit: Decodable {
        let usedPercentage: Double?
        let resetsAt: TimeInterval?
        enum CodingKeys: String, CodingKey {
            case usedPercentage = "used_percentage"
            case resetsAt = "resets_at"
        }
    }

    // MARK: - JSONL script schema

    private struct RawOutput: Decodable {
        let activeSession: RawSession?
        let weekly: RawWeekly?
        enum CodingKeys: String, CodingKey {
            case activeSession = "active_session"
            case weekly
        }
    }

    private struct RawSession: Decodable {
        let model: String?
        let costUsd: Double?
        let contextPct: Double?
        let session5hPct: Int?
        let sessionResetMins: Int?
        enum CodingKeys: String, CodingKey {
            case model
            case costUsd = "cost_usd"
            case contextPct = "context_pct"
            case session5hPct = "session_5h_pct"
            case sessionResetMins = "session_reset_mins"
        }
    }

    private struct RawWeekly: Decodable {
        let costUsd: Double?
        enum CodingKeys: String, CodingKey {
            case costUsd = "cost_usd"
        }
    }

    // MARK: - Embedded Python script (costs only — rate limits come from hook)

    private static let usageScript = #"""
import json, os, glob, time
from datetime import datetime, timezone

def cost_for(t):
    return (
        t['input']         * 3.00  / 1_000_000 +
        t['output']        * 15.00 / 1_000_000 +
        t['cache_read']    * 0.30  / 1_000_000 +
        t['cache_created'] * 3.75  / 1_000_000
    )

all_files = sorted(
    glob.glob(os.path.expanduser('~/.claude/projects/**/*.jsonl'), recursive=True),
    key=os.path.getmtime, reverse=True
)
all_files = [f for f in all_files if not f.endswith('.meta.json')]

now_ts   = time.time()
week_ago = now_ts - 7 * 86400
week_files = [f for f in all_files if os.path.getmtime(f) > week_ago]

def parse_file(path):
    tokens = {'input': 0, 'output': 0, 'cache_read': 0, 'cache_created': 0}
    model = None
    last_usage = None
    first_ts = None
    last_ts = None
    with open(path) as f:
        for line in f:
            try:
                rec = json.loads(line)
                ts = rec.get('timestamp')
                if ts:
                    if first_ts is None: first_ts = ts
                    last_ts = ts
                if rec.get('type') == 'assistant':
                    msg = rec.get('message', {})
                    m = msg.get('model')
                    if m: model = m
                    u = msg.get('usage', {})
                    if u:
                        last_usage = u
                        tokens['input']         += u.get('input_tokens',                0) or 0
                        tokens['output']        += u.get('output_tokens',               0) or 0
                        tokens['cache_read']    += u.get('cache_read_input_tokens',     0) or 0
                        tokens['cache_created'] += u.get('cache_creation_input_tokens', 0) or 0
            except:
                pass
    return {'tokens': tokens, 'model': model, 'last_usage': last_usage,
            'first_ts': first_ts, 'last_ts': last_ts}

if not all_files:
    print('{}')
    import sys; sys.exit(0)

s = parse_file(all_files[0])
tokens = s['tokens']
last_usage = s['last_usage']
model = s['model']

context_pct = 0
if last_usage:
    ctx_tokens = (
        (last_usage.get('input_tokens',                0) or 0) +
        (last_usage.get('cache_read_input_tokens',     0) or 0) +
        (last_usage.get('cache_creation_input_tokens', 0) or 0)
    )
    context_pct = round(ctx_tokens / 200_000 * 100, 1)

session_reset_mins = 0
if s['first_ts']:
    try:
        first_dt = datetime.fromisoformat(s['first_ts'].replace('Z', '+00:00'))
        now_dt = datetime.now(timezone.utc)
        elapsed_secs = (now_dt - first_dt).total_seconds()
        remaining = max(0, 5 * 3600 - elapsed_secs)
        session_reset_mins = int(remaining / 60)
    except:
        pass

session_cost = cost_for(tokens)

weekly_cost = 0
for path in week_files:
    ws = parse_file(path)
    weekly_cost += cost_for(ws['tokens'])

result = {
    'active_session': {
        'model': model,
        'cost_usd': round(session_cost, 4),
        'context_pct': context_pct,
        'session_reset_mins': session_reset_mins,
    },
    'weekly': {
        'cost_usd': round(weekly_cost, 4),
    },
}
print(json.dumps(result))
"""#
}

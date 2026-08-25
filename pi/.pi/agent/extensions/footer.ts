import type { ExtensionAPI } from '@earendil-works/pi-coding-agent';
import { truncateToWidth, visibleWidth } from '@earendil-works/pi-tui';
import { homedir } from 'node:os';

interface UsageTotals {
  input: number;
  output: number;
  cacheRead: number;
  cacheWrite: number;
  cost: number;
}

function createUsageTotals(): UsageTotals {
  return { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, cost: 0 };
}

function addUsage(
  totals: UsageTotals,
  usage: {
    input: number;
    output: number;
    cacheRead: number;
    cacheWrite: number;
    cost: { total: number };
  },
): void {
  totals.input += usage.input;
  totals.output += usage.output;
  totals.cacheRead += usage.cacheRead;
  totals.cacheWrite += usage.cacheWrite;
  totals.cost += usage.cost.total;
}

function fmt(n: number): string {
  if (n < 1000) return String(n);
  if (n < 10_000) return `${(n / 1000).toFixed(1)}k`;
  if (n < 1_000_000) return `${Math.round(n / 1000)}k`;
  if (n < 10_000_000) return `${(n / 1_000_000).toFixed(1)}M`;
  return `${Math.round(n / 1_000_000)}M`;
}

function formatCwd(cwd: string): string {
  const home = homedir();
  if (home && cwd.startsWith(home)) return `~${cwd.slice(home.length)}`;
  return cwd;
}

export default function (pi: ExtensionAPI) {
  pi.registerCommand('footer-reset', {
    description: 'Restore default pi footer',
    handler: async (_args, ctx) => {
      ctx.ui.setFooter(undefined);
      ctx.ui.notify('Default footer restored', 'info');
    },
  });

  pi.on('session_start', (_event, ctx) => {
    if (ctx.mode !== 'tui') return;

    const sessionCwd = ctx.cwd;

    ctx.ui.setFooter((tui, theme, footerData) => {
      const unsub = footerData.onBranchChange(() => tui.requestRender());

      let cachedTotals: UsageTotals | null = null;
      let cachedHitRate: number | undefined;
      let cachedCaveman = '';
      let lastEntryCount = -1;

      return {
        dispose: unsub,
        invalidate() {
          cachedTotals = null;
          lastEntryCount = -1;
        },
        render(width: number): string[] {
          const branch = footerData.getGitBranch();
          const entries = ctx.sessionManager.getEntries();

          if (lastEntryCount !== entries.length) {
            const totals = createUsageTotals();
            let hitRate: number | undefined;
            let caveman = '';

            for (const entry of entries) {
              if (
                entry.type === 'message' &&
                entry.message.role === 'assistant'
              ) {
                addUsage(totals, entry.message.usage);
                const pt =
                  entry.message.usage.input +
                  entry.message.usage.cacheRead +
                  entry.message.usage.cacheWrite;
                hitRate =
                  pt > 0
                    ? (entry.message.usage.cacheRead / pt) * 100
                    : undefined;
              } else if (
                entry.type === 'message' &&
                entry.message.role === 'toolResult' &&
                entry.message.usage
              ) {
                addUsage(totals, entry.message.usage);
              } else if (
                (entry.type === 'branch_summary' ||
                  entry.type === 'compaction') &&
                entry.usage
              ) {
                addUsage(totals, entry.usage);
              } else if (
                entry.type === 'custom' &&
                entry.customType === 'caveman-level' &&
                entry.data &&
                typeof (entry.data as { level: string }).level === 'string'
              ) {
                const level = (entry.data as { level: string }).level;
                if (level !== 'off') caveman = level.toUpperCase();
              }
            }

            cachedTotals = totals;
            cachedHitRate = hitRate;
            cachedCaveman = caveman;
            lastEntryCount = entries.length;
          }

          const totals = cachedTotals;
          const latestCacheHitRate = cachedHitRate;
          const cavemanLabel = cachedCaveman;

          const contextUsage = ctx.getContextUsage();
          const contextWindow = contextUsage?.contextWindow ?? 0;
          const contextPct = contextUsage?.percent;
          const contextDisplay =
            contextPct !== null && contextPct !== undefined
              ? `${contextPct.toFixed(1)}%`
              : '?%';
          const contextStr = `${contextDisplay}/${fmt(contextWindow)}`;
          const pctVal = contextPct ?? 0;

          const plainParts: string[] = [];
          if (totals?.input) plainParts.push(`↑${fmt(totals.input)}`);
          if (totals?.output) plainParts.push(`↓${fmt(totals.output)}`);
          if (totals?.cacheRead) plainParts.push(`R${fmt(totals.cacheRead)}`);
          if ((totals?.cacheRead ?? 0) > 0 || (totals?.cacheWrite ?? 0) > 0) {
            if (latestCacheHitRate !== undefined) {
              plainParts.push(`CH${latestCacheHitRate.toFixed(1)}%`);
            }
          }
          if (totals?.cost) plainParts.push(`$${totals.cost.toFixed(3)}`);
          plainParts.push(contextStr);

          const leftPlain = plainParts.join(' ');
          const leftPlainW = visibleWidth(leftPlain);

          const modelName = ctx.model?.id ?? 'no-model';
          let effort: string | null = null;
          if (ctx.thinkingLevel && ctx.model?.reasoning) {
            effort =
              ctx.thinkingLevel === 'off' ? 'thinking off' : ctx.thinkingLevel;
          }

          const rightParts: string[] = [modelName];
          if (effort) rightParts.push(effort);
          if (cavemanLabel) rightParts.push(cavemanLabel);
          const rightSide = rightParts.join(' • ');
          const rightSideW = visibleWidth(rightSide);

          const minPad = 2;
          const totalNeeded = leftPlainW + minPad + rightSideW;

          let padding: string;
          let rightFinal: string;
          if (totalNeeded <= width) {
            padding = ' '.repeat(width - leftPlainW - rightSideW);
            rightFinal = rightSide;
          } else {
            const avail = width - leftPlainW - minPad;
            if (avail > 0) {
              rightFinal = truncateToWidth(rightSide, avail, '');
              padding = ' '.repeat(
                Math.max(0, width - leftPlainW - visibleWidth(rightFinal)),
              );
            } else {
              padding = '';
              rightFinal = '';
            }
          }

          const bright = (s: string) => theme.fg('text', s);
          const muted = (s: string) => theme.fg('muted', s);

          const coloredParts: string[] = [];
          if (totals?.input) coloredParts.push(bright(`↑${fmt(totals.input)}`));
          if (totals?.output)
            coloredParts.push(bright(`↓${fmt(totals.output)}`));
          if (totals?.cacheRead)
            coloredParts.push(bright(`R${fmt(totals.cacheRead)}`));
          if (
            ((totals?.cacheRead ?? 0) > 0 || (totals?.cacheWrite ?? 0) > 0) &&
            latestCacheHitRate !== undefined
          ) {
            coloredParts.push(bright(`CH${latestCacheHitRate.toFixed(1)}%`));
          }
          if (totals?.cost)
            coloredParts.push(bright(`$${totals.cost.toFixed(3)}`));
          if (pctVal > 90) {
            coloredParts.push(theme.fg('error', contextStr));
          } else if (pctVal > 70) {
            coloredParts.push(theme.fg('warning', contextStr));
          } else {
            coloredParts.push(bright(contextStr));
          }
          const leftColored = coloredParts.join(' ');
          const statsLine = leftColored + muted(padding + rightFinal);

          const cwd = formatCwd(sessionCwd);
          const branchIcon = '\uf418';
          let line1: string;
          if (branch) {
            const raw = `${cwd}  ${branchIcon} ${branch}`;
            if (visibleWidth(raw) <= width) {
              line1 = `${muted(cwd)}  ${muted(`${branchIcon} ${branch}`)}`;
            } else {
              line1 = truncateToWidth(muted(raw), width, muted('...'));
            }
          } else {
            line1 = muted(cwd);
          }

          return [line1, statsLine];
        },
      };
    });
  });
}

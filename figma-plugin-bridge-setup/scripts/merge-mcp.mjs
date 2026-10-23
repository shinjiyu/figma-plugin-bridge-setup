// bun merge-mcp.mjs <mcp.json> <bunPath> <serverTs>
// 把 TalkToFigma 合并进 Cursor 的 mcp.json，保留其他服务器。
import fs from "fs";
import path from "path";

const [file, bunPath, serverTs] = process.argv.slice(2);
fs.mkdirSync(path.dirname(file), { recursive: true });
let cfg = { mcpServers: {} };
if (fs.existsSync(file)) {
  const raw = fs.readFileSync(file, "utf8").replace(/^\uFEFF/, "");
  if (raw.trim()) {
    try {
      cfg = JSON.parse(raw);
    } catch (e) {
      console.log(`ERROR: mcp.json 不是合法 JSON（${e.message}），未修改。请修好后重跑。`);
      process.exit(2);
    }
  }
  fs.copyFileSync(file, file + ".bak");
}
cfg.mcpServers ??= {};
const next = { command: bunPath, args: [serverTs] };
const same = JSON.stringify(cfg.mcpServers.TalkToFigma) === JSON.stringify(next);
cfg.mcpServers.TalkToFigma = next;
fs.writeFileSync(file, JSON.stringify(cfg, null, 2) + "\n");
console.log(same ? "mcp.json 已是最新" : "mcp.json 已写入 TalkToFigma");

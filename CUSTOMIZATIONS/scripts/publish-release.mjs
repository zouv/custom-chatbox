#!/usr/bin/env node
/**
 * publish-release.mjs —— 把已打好的安装包发布到 GitHub Release
 *
 * 配套 skill：.agents/skills/chatbox-publish/SKILL.md
 * 背景：本机未安装 gh CLI，改用 Git Credential Manager 里的 token 走 GitHub REST API。
 *       全程幂等：release 已存在则复用，同名资产先删后传，可反复重跑。
 *
 * 用法（在仓库根目录执行）：
 *   node CUSTOMIZATIONS/scripts/publish-release.mjs v1.23.0-custom.3
 *   node CUSTOMIZATIONS/scripts/publish-release.mjs v1.23.0-custom.3 --dry-run
 *   node CUSTOMIZATIONS/scripts/publish-release.mjs v1.23.0-custom.3 \
 *     --notes CUSTOMIZATIONS/release-notes/v1.23.0-custom.3.md \
 *     --asset release/build/Chatbox-1.23.0-custom.3-Setup.exe \
 *     --asset release/build/Chatbox-1.23.0-custom.3-Setup.exe.blockmap
 *
 * 默认值：
 *   --notes   CUSTOMIZATIONS/release-notes/<version>.md
 *   --asset   release/build/Chatbox-<version 去掉 v>-Setup.exe 及其 .blockmap
 *   --repo    从 `git remote get-url origin` 推导（支持 https / ssh 两种写法）
 *
 * 退出码：0 成功；1 失败；2 参数错误
 */
import fs from 'node:fs'
import path from 'node:path'
import { execFileSync } from 'node:child_process'

const REPO_ROOT = execFileSync('git', ['rev-parse', '--show-toplevel'], { encoding: 'utf8' }).trim()

function die(msg, code = 1) {
  console.error(`[err ] ${msg}`)
  process.exit(code)
}
const info = (m) => console.log(`[info] ${m}`)
const ok = (m) => console.log(`[ ok ] ${m}`)

// ---------- 参数解析 ----------
const argv = process.argv.slice(2)
const version = argv.find((a) => !a.startsWith('--') && /^v\d/.test(a))
if (!version) die('缺少版本号，例：node publish-release.mjs v1.23.0-custom.3', 2)

const flags = {}
const assets = []
for (let i = 0; i < argv.length; i++) {
  const a = argv[i]
  if (a === '--asset') {
    assets.push(argv[++i])
  } else if (a.startsWith('--')) {
    flags[a.slice(2)] = argv[i + 1] && !argv[i + 1].startsWith('--') ? argv[++i] : true
  }
}
const dryRun = Boolean(flags['dry-run'])

const appVersion = version.replace(/^v/, '')

function resolveRepo() {
  if (typeof flags.repo === 'string') return flags.repo
  const url = execFileSync('git', ['remote', 'get-url', 'origin'], { encoding: 'utf8' }).trim()
  const m = url.match(/github\.com[:/]([^/]+\/[^/]+?)(?:\.git)?$/)
  if (!m) die(`无法从 origin（${url}）解析出 owner/repo，请用 --repo 指定`)
  return m[1]
}
const repo = resolveRepo()

const notesFile = path.resolve(REPO_ROOT, typeof flags.notes === 'string' ? flags.notes : `CUSTOMIZATIONS/release-notes/${version}.md`)

const assetPaths = (
  assets.length
    ? assets
    : [
        `release/build/Chatbox-${appVersion}-Setup.exe`,
        `release/build/Chatbox-${appVersion}-Setup.exe.blockmap`,
      ]
).map((p) => path.resolve(REPO_ROOT, p))

const targetCommitish = typeof flags.target === 'string' ? flags.target : 'custom/main'
const isPrerelease = Boolean(flags.prerelease)
const isDraft = Boolean(flags.draft)

// ---------- 前置校验 ----------
info(`仓库      : ${repo}`)
info(`版本      : ${version}（产物名用 ${appVersion}）`)
info(`release notes: ${notesFile}`)
for (const p of assetPaths) info(`产物      : ${p}`)

if (!fs.existsSync(notesFile)) die(`release notes 不存在：${notesFile}（先写 CUSTOMIZATIONS/release-notes/${version}.md）`)
const assetStats = assetPaths.map((p) => {
  if (!fs.existsSync(p)) die(`产物不存在：${p}（先跑 sh CUSTOMIZATIONS/scripts/manager.sh setup）`)
  return { path: p, name: path.basename(p), size: fs.statSync(p).size }
})
ok(`前置校验通过（${assetStats.length} 个产物，共 ${(assetStats.reduce((s, a) => s + a.size, 0) / 1024 / 1024).toFixed(1)} MB）`)

// 本地打 tag 但未推送是常见疏漏——提示但不阻断
try {
  const localTag = execFileSync('git', ['rev-parse', `${version}^{tag}`], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).trim()
  info(`本地 tag  : ${localTag}`)
  try {
    execFileSync('git', ['merge-base', '--is-ancestor', version, 'HEAD'], { stdio: 'ignore' })
  } catch {
    console.warn(`[warn] ${version} 不是 HEAD 的祖先——tag 可能打在被 amend/改写过的提交上（见 pitfalls #12），release 的 tag 页会指向游离提交`)
  }
} catch {
  console.warn(`[warn] 本地不存在 tag ${version}，先执行：git tag -a ${version} -m "Release ${version}"`)
}

if (dryRun) {
  console.log('\n[dry-run] 校验完成，未发起任何网络请求')
  process.exit(0)
}

// ---------- 取 token（GCM，不落盘） ----------
function getToken() {
  let out
  try {
    out = execFileSync('git', ['credential', 'fill'], {
      input: 'protocol=https\nhost=github.com\n\n',
      encoding: 'utf8',
    })
  } catch {
    die('无法从 Git Credential Manager 取到 github.com 凭证；可改用 `winget install GitHub.cli` + `gh auth login`')
  }
  const m = out.match(/^password=(.+)$/m)
  if (!m) die('GCM 返回的凭证里没有 password 字段（可能只存了用户名）')
  return m[1].trim()
}
const token = getToken()
ok('已从 Git Credential Manager 取到 token')

const api = `https://api.github.com/repos/${repo}`
const headers = {
  Authorization: `token ${token}`,
  Accept: 'application/vnd.github+json',
  'X-GitHub-Api-Version': '2022-11-28',
  'User-Agent': 'chatbox-publish-script',
}

// ---------- 创建（或复用）release ----------
let release = null
const existing = await fetch(`${api}/releases/tags/${version}`, { headers })
if (existing.status === 200) {
  release = await existing.json()
  info(`release ${version} 已存在（id=${release.id}），复用`)
} else if (existing.status === 404) {
  const res = await fetch(`${api}/releases`, {
    method: 'POST',
    headers: { ...headers, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      tag_name: version,
      target_commitish: targetCommitish,
      name: version,
      body: fs.readFileSync(notesFile, 'utf8'),
      draft: isDraft,
      prerelease: isPrerelease,
    }),
  })
  if (!res.ok) die(`创建 release 失败 ${res.status}：${await res.text()}`)
  release = await res.json()
  ok(`release ${version} 已创建（id=${release.id}）`)
} else {
  die(`查询 release 失败 ${existing.status}：${await existing.text()}`)
}

// ---------- 上传产物 ----------
for (const asset of assetStats) {
  const dupe = (release.assets || []).find((a) => a.name === asset.name)
  if (dupe) {
    info(`资产 ${asset.name} 已存在（id=${dupe.id}），先删除旧资产再上传`)
    const del = await fetch(`${api}/releases/assets/${dupe.id}`, { method: 'DELETE', headers })
    if (!del.ok) die(`删除旧资产失败 ${del.status}：${await del.text()}`)
  }
  info(`上传 ${asset.name}（${(asset.size / 1024 / 1024).toFixed(1)} MB）...`)
  const up = await fetch(
    `https://uploads.github.com/repos/${repo}/releases/${release.id}/assets?name=${encodeURIComponent(asset.name)}`,
    {
      method: 'POST',
      headers: {
        Authorization: `token ${token}`,
        'Content-Type': 'application/octet-stream',
        'Content-Length': String(asset.size),
        'User-Agent': 'chatbox-publish-script',
      },
      body: fs.createReadStream(asset.path),
      duplex: 'half',
    },
  )
  if (!up.ok) die(`上传 ${asset.name} 失败 ${up.status}：${await up.text()}`)
  const upJson = await up.json()
  if (upJson.size !== asset.size) die(`${asset.name} 上传后字节数不符：本地 ${asset.size}，远端 ${upJson.size}`)
  ok(`${asset.name} 上传完成（${upJson.size} bytes，与本地一致）`)
}

console.log(`\n[SUCCESS] ${release.html_url}`)

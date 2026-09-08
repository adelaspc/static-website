import { execFileSync } from "node:child_process";
import { access, cp, mkdir, mkdtemp, readFile, rm, symlink } from "node:fs/promises";
import path from "node:path";
import { tmpdir } from "node:os";

const htmlFiles = [
  "index.html",
  "aws-3tier-architecture.html",
  "autodeploy-platform.html",
  "static-website.html",
  "error.html",
];

const workspaceRoot = await mkdtemp(path.join(tmpdir(), "portfolio-site-test-"));
const appRoot = path.join(workspaceRoot, "portfolio-site");
const docsRoot = path.join(workspaceRoot, "docs", "diagrams");

try {
  await mkdir(appRoot, { recursive: true });
  await mkdir(docsRoot, { recursive: true });
  await cp("package.json", path.join(appRoot, "package.json"));
  await cp("package-lock.json", path.join(appRoot, "package-lock.json"));
  await cp("assets", path.join(appRoot, "assets"), { recursive: true });
  await cp("images", path.join(appRoot, "images"), { recursive: true });
  await cp("scripts", path.join(appRoot, "scripts"), { recursive: true });
  await cp("src", path.join(appRoot, "src"), { recursive: true });
  for (const file of htmlFiles) {
    await cp(file, path.join(appRoot, file));
  }
  await cp("../docs/diagrams", docsRoot, { recursive: true });
  await symlink(path.join(process.cwd(), "node_modules"), path.join(appRoot, "node_modules"), "dir");

  execFileSync("npm", ["run", "build"], { cwd: appRoot, stdio: "inherit" });

  for (const file of htmlFiles) {
    await access(path.join(appRoot, "dist", file));
    const sourceHtml = await readFile(path.join(appRoot, file), "utf8");
    const html = await readFile(path.join(appRoot, "dist", file), "utf8");

    const cssMatch = html.match(/assets\/styles\.([a-f0-9]{12})\.css/);
    const jsMatch = html.match(/assets\/site\.([a-f0-9]{12})\.js/);
    if (!cssMatch) throw new Error(`dist/${file}: missing hashed CSS asset reference`);
    await access(path.join(appRoot, "dist", "assets", `styles.${cssMatch[1]}.css`));

    const expectsJavaScript = /<script\b[^>]*\bsrc=["']assets\/site\.js["']/i.test(sourceHtml);
    if (expectsJavaScript && !jsMatch) {
      throw new Error(`dist/${file}: missing hashed JavaScript asset reference`);
    }
    if (!expectsJavaScript && jsMatch) {
      throw new Error(`dist/${file}: contains an unexpected JavaScript asset reference`);
    }
    if (jsMatch) {
      await access(path.join(appRoot, "dist", "assets", `site.${jsMatch[1]}.js`));
    }

    for (const [, reference] of html.matchAll(/(?:src|href)=["']([^"']+)["']/g)) {
      if (/^(?:https?:|mailto:|data:|javascript:|#)/i.test(reference)) continue;
      const [target, fragment] = reference.split("#", 2);
      const targetPath = path.join(appRoot, "dist", target || file);
      await access(targetPath);
      if (fragment) {
        const targetHtml = await readFile(targetPath, "utf8");
        if (!new RegExp(`(?:id|name)=["']${fragment.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}["']`).test(targetHtml)) {
          throw new Error(`dist/${file}: missing anchor #${fragment} in ${target}`);
        }
      }
    }
  }

  await access(path.join(appRoot, "dist", "assets"));
  await access(path.join(appRoot, "dist", "images"));
  console.log(`Build smoke test passed for ${htmlFiles.length} HTML files and local references`);
} finally {
  await rm(workspaceRoot, { recursive: true, force: true });
}

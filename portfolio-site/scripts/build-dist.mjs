import { createHash } from "node:crypto";
import { cp, mkdir, readFile, rm, writeFile } from "node:fs/promises";
import path from "node:path";

const distDir = "dist";
const htmlFiles = ["index.html", "project-1.html", "project-2.html"];
const cssSource = "assets/styles.css";

const hashFile = async (file) => {
  const contents = await readFile(file);
  return createHash("sha256").update(contents).digest("hex").slice(0, 12);
};

await rm(distDir, { recursive: true, force: true });
await mkdir(path.join(distDir, "assets"), { recursive: true });

const cssHash = await hashFile(cssSource);
const hashedCssFile = `styles.${cssHash}.css`;
const hashedCssPath = path.join("assets", hashedCssFile);

await cp(cssSource, path.join(distDir, hashedCssPath));
await cp("images", path.join(distDir, "images"), { recursive: true });
await cp("app_UI_landing.png", path.join(distDir, "app_UI_landing.png"));
await cp("app_ui_projects.png", path.join(distDir, "app_ui_projects.png"));

for (const file of htmlFiles) {
  const html = await readFile(file, "utf8");
  const rewrittenHtml = html.replaceAll("assets/styles.css", hashedCssPath.replaceAll(path.sep, "/"));
  await writeFile(path.join(distDir, file), rewrittenHtml);
}

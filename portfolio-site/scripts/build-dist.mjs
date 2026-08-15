import { createHash } from "node:crypto";
import { cp, mkdir, readFile, rm, writeFile } from "node:fs/promises";
import path from "node:path";

const distDir = "dist";
const htmlFiles = ["index.html", "aws-3tier-architecture.html", "autodeploy-platform.html", "static-website.html", "error.html"];
const cssSource = "assets/styles.css";
const jsSource = "assets/site.js";

const hashFile = async (file) => {
  const contents = await readFile(file);
  return createHash("sha256").update(contents).digest("hex").slice(0, 12);
};

await rm(distDir, { recursive: true, force: true });
await mkdir(path.join(distDir, "assets"), { recursive: true });

const cssHash = await hashFile(cssSource);
const hashedCssFile = `styles.${cssHash}.css`;
const hashedCssPath = path.join("assets", hashedCssFile);
const jsHash = await hashFile(jsSource);
const hashedJsFile = `site.${jsHash}.js`;
const hashedJsPath = path.join("assets", hashedJsFile);

await cp(cssSource, path.join(distDir, hashedCssPath));
await cp(jsSource, path.join(distDir, hashedJsPath));
await cp("images", path.join(distDir, "images"), { recursive: true });
const projectDiagrams = {
  "../docs/diagrams/acm-validation-flow.png": "acm-validation-flow.png",
  "../docs/diagrams/bootstrap.png": "bootstrap.png",
  "../docs/diagrams/dependency-graph.png": "dependency-graph.png",
  "../docs/diagrams/maindeployflow.png": "main-deploy-flow.png",
};
for (const [source, filename] of Object.entries(projectDiagrams)) {
  await cp(source, path.join(distDir, "images", filename));
}

for (const file of htmlFiles) {
  const html = await readFile(file, "utf8");
  const rewrittenHtml = html
    .replaceAll("assets/styles.css", hashedCssPath.replaceAll(path.sep, "/"))
    .replaceAll("assets/site.js", hashedJsPath.replaceAll(path.sep, "/"));
  await writeFile(path.join(distDir, file), rewrittenHtml);
}

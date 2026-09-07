import { execFileSync } from "node:child_process";
import { readFile } from "node:fs/promises";

const htmlFiles = [
  "index.html",
  "aws-3tier-architecture.html",
  "autodeploy-platform.html",
  "static-website.html",
  "error.html",
];

execFileSync(process.execPath, ["--check", "assets/site.js"], { stdio: "inherit" });

for (const file of htmlFiles) {
  const html = await readFile(file, "utf8");
  const required = [
    ["DOCTYPE declaration", /<!doctype html>/i],
    ["language attribute", /<html\b[^>]*\blang=["'][^"']+["']/i],
    ["title element", /<title>[^<]+<\/title>/i],
    ["charset declaration", /<meta\b[^>]*charset=["']?utf-8/i],
    ["viewport declaration", /<meta\b[^>]*name=["']viewport["']/i],
  ];

  for (const [description, pattern] of required) {
    if (!pattern.test(html)) {
      throw new Error(`${file}: missing ${description}`);
    }
  }

  for (const image of html.matchAll(/<img\b[^>]*>/gi)) {
    if (!/\balt=["'][^"']*["']/i.test(image[0])) {
      throw new Error(`${file}: image is missing an alt attribute`);
    }
  }

}

console.log(`Lint passed for ${htmlFiles.length} HTML files and assets/site.js`);

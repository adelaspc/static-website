import { access, readdir, readFile } from "node:fs/promises";
import path from "node:path";

const repositoryRoot = process.cwd();
const markdownFiles = [];

const collectMarkdownFiles = async (directory) => {
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    if (entry.name === ".git" || entry.name === "node_modules") continue;
    const entryPath = path.join(directory, entry.name);
    if (entry.isDirectory()) {
      await collectMarkdownFiles(entryPath);
    } else if (entry.isFile() && entry.name.endsWith(".md")) {
      markdownFiles.push(entryPath);
    }
  }
};

await collectMarkdownFiles(repositoryRoot);

for (const file of markdownFiles) {
  const markdown = await readFile(file, "utf8");
  for (const match of markdown.matchAll(/!?\[[^\]]*\]\(([^)\s]+)(?:\s+["'][^)]*["'])?\)/g)) {
    const reference = match[1].replace(/^<|>$/g, "");
    if (/^(?:https?:|mailto:|data:|#)/i.test(reference)) continue;

    const [target] = reference.split("#", 1);
    const resolved = target.startsWith("/")
      ? path.join(repositoryRoot, target)
      : path.resolve(path.dirname(file), target);
    try {
      await access(resolved);
    } catch {
      const relativeFile = path.relative(repositoryRoot, file);
      throw new Error(`${relativeFile}: broken local reference ${reference}`);
    }
  }
}

console.log(`Documentation link check passed for ${markdownFiles.length} Markdown files`);

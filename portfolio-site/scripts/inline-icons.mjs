import { icons } from "lucide";
import { readFile, writeFile } from "node:fs/promises";

const files = ["index.html", "aws-3tier-architecture.html", "autodeploy-platform.html", "project-3.html", "error.html"];
const attrsToString = (attrs) =>
  attrs
    .map(([name, value]) => `${name}="${String(value).replaceAll('"', "&quot;")}"`)
    .join(" ");

const toPascalCase = (name) =>
  name
    .split("-")
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join("");

for (const file of files) {
  let html = await readFile(file, "utf8");
  html = html.replace(/<i\s+data-lucide="([^"]+)"\s+class="([^"]+)"\s*><\/i>/g, (match, iconName, className) => {
    const children = icons[toPascalCase(iconName)];
    if (!children) {
      throw new Error(`Missing lucide icon "${iconName}" in ${file}`);
    }

    const svgAttrs = attrsToString([
      ["xmlns", "http://www.w3.org/2000/svg"],
      ["width", "24"],
      ["height", "24"],
      ["viewBox", "0 0 24 24"],
      ["fill", "none"],
      ["stroke", "currentColor"],
      ["stroke-width", "2"],
      ["stroke-linecap", "round"],
      ["stroke-linejoin", "round"],
      ["class", className],
      ["aria-hidden", "true"],
      ["focusable", "false"],
    ]);
    const body = children.map(([childTag, childAttrs]) => `<${childTag} ${attrsToString(Object.entries(childAttrs))} />`).join("");
    return `<svg ${svgAttrs}>${body}</svg>`;
  });
  html = html.replace(/\n\s*<script>\s*lucide\.createIcons\(\);\s*<\/script>\s*/g, "\n");
  await writeFile(file, html);
}

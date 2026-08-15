const qs = (selector, root = document) => root.querySelector(selector);
const qsa = (selector, root = document) => [...root.querySelectorAll(selector)];

const navLinks = qsa("[data-section-link]");
const sections = navLinks.map((link) => qs(link.hash)).filter(Boolean);
const projectNav = navLinks[0]?.closest(".project-nav");
if (sections.length) {
  let activeSectionId = "";
  let scrollFrame;

  const updateActiveSection = () => {
    const navBottom = projectNav?.getBoundingClientRect().bottom ?? 0;
    const probeY = navBottom + (window.innerHeight - navBottom) * 0.28;
    const activeSection = sections.reduce((active, section) =>
      section.getBoundingClientRect().top <= probeY ? section : active, sections[0]);

    if (activeSection.id === activeSectionId) return;
    activeSectionId = activeSection.id;
    navLinks.forEach((link) => link.setAttribute("aria-current", String(link.hash === `#${activeSectionId}`)));

    const activeLink = qs(`[data-section-link][href="#${activeSectionId}"]`);
    if (activeLink && projectNav) {
      projectNav.scrollTo({
        left: activeLink.offsetLeft - (projectNav.clientWidth - activeLink.clientWidth) / 2,
        behavior: window.matchMedia("(prefers-reduced-motion: reduce)").matches ? "auto" : "smooth",
      });
    }
  };

  const queueActiveSectionUpdate = () => {
    cancelAnimationFrame(scrollFrame);
    scrollFrame = requestAnimationFrame(updateActiveSection);
  };

  window.addEventListener("scroll", queueActiveSectionUpdate, { passive: true });
  window.addEventListener("resize", queueActiveSectionUpdate);
  updateActiveSection();
}

let activeLightbox;
let previousFocus;
const lightbox = qs("[data-lightbox]");
const lightboxImage = qs("[data-lightbox-image]");
const lightboxPlaceholder = qs("[data-lightbox-placeholder]");
const lightboxCaption = qs("[data-lightbox-caption]");

const renderLightbox = () => {
  if (!activeLightbox || !lightbox) return;
  const { slides, index } = activeLightbox;
  const slide = slides[index];
  const image = qs("img", slide) || qs("img", slide.closest(".architecture-diagram-panel"));
  lightboxImage.hidden = !image;
  lightboxPlaceholder.hidden = Boolean(image);
  if (image) {
    lightboxImage.src = image.currentSrc || image.src;
    lightboxImage.alt = image.alt;
  }
  lightboxCaption.textContent = `${slide.dataset.caption || image?.alt || "Project screenshot"} · ${index + 1}/${slides.length}`;
};

const moveLightbox = (delta) => {
  if (!activeLightbox) return;
  activeLightbox.index = (activeLightbox.index + delta + activeLightbox.slides.length) % activeLightbox.slides.length;
  renderLightbox();
};

const closeLightbox = () => {
  if (!lightbox || lightbox.hidden) return;
  lightbox.hidden = true;
  document.body.classList.remove("lightbox-open");
  activeLightbox = undefined;
  previousFocus?.focus();
};

qsa("[data-carousel]").forEach((carousel) => {
  const slides = qsa("[data-slide]", carousel);
  const dots = qs("[data-dots]", carousel);
  const counter = qs("[data-counter]", carousel);
  let index = 0;
  let touchStart = 0;

  slides.forEach((_, dotIndex) => {
    const dot = document.createElement("button");
    dot.type = "button";
    dot.className = "h-2 w-2 rounded-full bg-slate-600 transition-colors";
    dot.setAttribute("aria-label", `Show screenshot ${dotIndex + 1}`);
    dot.addEventListener("click", () => show(dotIndex));
    dots?.append(dot);
  });

  const show = (nextIndex) => {
    index = (nextIndex + slides.length) % slides.length;
    slides.forEach((slide, slideIndex) => slide.dataset.active = String(slideIndex === index));
    qsa("button", dots).forEach((dot, dotIndex) => dot.classList.toggle("bg-accent", dotIndex === index));
    if (counter) counter.textContent = `${index + 1} / ${slides.length}`;
  };

  qs("[data-prev]", carousel)?.addEventListener("click", () => show(index - 1));
  qs("[data-next]", carousel)?.addEventListener("click", () => show(index + 1));
  carousel.addEventListener("keydown", (event) => {
    if (event.key === "ArrowLeft") show(index - 1);
    if (event.key === "ArrowRight") show(index + 1);
  });
  carousel.addEventListener("touchstart", (event) => touchStart = event.changedTouches[0].clientX, { passive: true });
  carousel.addEventListener("touchend", (event) => {
    const distance = event.changedTouches[0].clientX - touchStart;
    if (Math.abs(distance) > 50) show(index + (distance < 0 ? 1 : -1));
  }, { passive: true });
  slides.forEach((slide, slideIndex) => slide.addEventListener("click", () => {
    if (!lightbox) return;
    previousFocus = document.activeElement;
    activeLightbox = { slides, index: slideIndex };
    renderLightbox();
    lightbox.hidden = false;
    document.body.classList.add("lightbox-open");
    qs("[data-lightbox-close]", lightbox)?.focus();
  }));
  show(0);
});

qsa("[data-enlarge]").forEach((trigger) => trigger.addEventListener("click", () => {
  if (!lightbox) return;
  previousFocus = document.activeElement;
  activeLightbox = { slides: [trigger], index: 0 };
  renderLightbox();
  lightbox.hidden = false;
  document.body.classList.add("lightbox-open");
  qs("[data-lightbox-close]", lightbox)?.focus();
}));

qs("[data-lightbox-close]")?.addEventListener("click", closeLightbox);
qs("[data-lightbox-prev]")?.addEventListener("click", () => moveLightbox(-1));
qs("[data-lightbox-next]")?.addEventListener("click", () => moveLightbox(1));
lightbox?.addEventListener("click", (event) => { if (event.target === lightbox) closeLightbox(); });
document.addEventListener("keydown", (event) => {
  if (!activeLightbox) return;
  if (event.key === "Escape") closeLightbox();
  if (event.key === "ArrowLeft") moveLightbox(-1);
  if (event.key === "ArrowRight") moveLightbox(1);
  if (event.key === "Tab") {
    const controls = qsa("button", lightbox).filter((button) => !button.hidden);
    const first = controls[0];
    const last = controls.at(-1);
    if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last.focus(); }
    else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first.focus(); }
  }
});

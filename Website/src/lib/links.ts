const base = import.meta.env.BASE_URL;

/** Returns a path that respects Astro's configured deployment base. */
export function internalPath(path: string): string {
  return `${base.replace(/\/$/, "")}${path}`;
}

export const repositoryURL = "https://github.com/modern-swift-dev/skein-swift";
export const rawRepositoryURL = "https://raw.githubusercontent.com/modern-swift-dev/skein-swift/main";

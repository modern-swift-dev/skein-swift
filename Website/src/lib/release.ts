export interface Release {
  version: string;
  publishedAt: Date;
  url: string;
  notes: string;
}

let releasePromise: Promise<Release> | undefined;

function fail(message: string): never {
  throw new Error(`Unable to load the latest Skein release: ${message}`);
}

function stringField(value: Record<string, unknown>, name: string): string {
  const field = value[name];
  if (typeof field !== "string" || field.trim() === "") {
    return fail(`GitHub returned an invalid ${name} field.`);
  }
  return field;
}

function parseRelease(value: unknown): Release {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    return fail("GitHub returned an unexpected response.");
  }
  const record = value as Record<string, unknown>;
  if (record.draft !== false || record.prerelease !== false) {
    return fail("GitHub returned a draft or prerelease instead of a stable release.");
  }

  const version = stringField(record, "tag_name");
  const publishedAt = new Date(stringField(record, "published_at"));
  const url = stringField(record, "html_url");
  const notes = typeof record.body === "string" ? record.body.trim() : "";

  if (Number.isNaN(publishedAt.valueOf())) {
    return fail("GitHub returned an invalid publication date.");
  }
  try {
    const parsedURL = new URL(url);
    if (parsedURL.protocol !== "https:") {
      return fail("GitHub returned a non-HTTPS release URL.");
    }
  } catch {
    return fail("GitHub returned an invalid release URL.");
  }
  if (!/^v?\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$/.test(version)) {
    return fail("GitHub returned an invalid release version.");
  }
  return { version, publishedAt, url, notes };
}

/** Fetches and validates the latest stable GitHub release once per Astro build. */
export function latestRelease(): Promise<Release> {
  releasePromise ??= (async () => {
    const token = import.meta.env.GITHUB_TOKEN;
    let response: Response;
    try {
      response = await fetch("https://api.github.com/repos/modern-swift-dev/skein-swift/releases/latest", {
        headers: {
          Accept: "application/vnd.github+json",
          "User-Agent": "skein-swift-website",
          ...(token ? { Authorization: `Bearer ${token}` } : {})
        }
      });
    } catch (error) {
      return fail(`request failed${error instanceof Error ? `: ${error.message}` : "."}`);
    }
    if (!response.ok) {
      return fail(`GitHub responded with HTTP ${response.status}.`);
    }
    let payload: unknown;
    try {
      payload = await response.json();
    } catch {
      return fail("GitHub did not return JSON.");
    }
    return parseRelease(payload);
  })();
  return releasePromise;
}

import * as fs from "fs";
import * as path from "path";
import * as os from "os";

export interface Project {
  name: string;
  path: string;
  tags: string[];
  isPinned: boolean;
  addedAt?: string;
  notes?: string;
}

export interface HealthDetails {
  totalScore: number;
  category: string;
  hasRecentCommits: boolean;
  noUncommittedChanges: boolean;
  noUnpushedCommits: boolean;
}

export interface CachedHealth {
  details: HealthDetails;
  cachedAt: string;
}

const DATA_DIR = path.join(os.homedir(), ".project_launcher");

export function loadProjects(): Project[] {
  const filePath = path.join(DATA_DIR, "projects.json");
  if (!fs.existsSync(filePath)) return [];
  try {
    return JSON.parse(fs.readFileSync(filePath, "utf-8")) as Project[];
  } catch {
    return [];
  }
}

export function loadHealthScores(): Record<string, CachedHealth> {
  const filePath = path.join(DATA_DIR, "health_cache.json");
  if (!fs.existsSync(filePath)) return {};
  try {
    return JSON.parse(fs.readFileSync(filePath, "utf-8")) as Record<string, CachedHealth>;
  } catch {
    return {};
  }
}

export function getHealthIcon(score: number | undefined): string {
  if (score === undefined) return "⚪";
  if (score >= 80) return "🟢";
  if (score >= 50) return "🟡";
  return "🔴";
}

export function getHealthLabel(score: number | undefined): string {
  if (score === undefined) return "Not scored";
  if (score >= 80) return "Healthy";
  if (score >= 50) return "Needs Attention";
  return "Critical";
}

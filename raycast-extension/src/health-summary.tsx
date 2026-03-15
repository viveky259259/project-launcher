import { List, Icon, Color } from "@raycast/api";
import { loadProjects, loadHealthScores } from "./data";

export default function HealthSummary() {
  const projects = loadProjects();
  const scores = loadHealthScores();

  let healthy = 0,
    attention = 0,
    critical = 0,
    unscored = 0;

  const criticalProjects: { name: string; score: number }[] = [];

  for (const project of projects) {
    const health = scores[project.path];
    const score = health?.details?.totalScore;
    if (score === undefined) {
      unscored++;
    } else if (score >= 80) {
      healthy++;
    } else if (score >= 50) {
      attention++;
    } else {
      critical++;
      criticalProjects.push({ name: project.name, score });
    }
  }

  return (
    <List>
      <List.Section title="Overview">
        <List.Item
          title="Total Projects"
          subtitle={`${projects.length}`}
          icon={{ source: Icon.Folder, tintColor: Color.Blue }}
        />
        <List.Item
          title="Healthy"
          subtitle={`${healthy}`}
          icon={{ source: Icon.CircleFilled, tintColor: Color.Green }}
        />
        <List.Item
          title="Needs Attention"
          subtitle={`${attention}`}
          icon={{ source: Icon.CircleFilled, tintColor: Color.Yellow }}
        />
        <List.Item
          title="Critical"
          subtitle={`${critical}`}
          icon={{ source: Icon.CircleFilled, tintColor: Color.Red }}
        />
        {unscored > 0 && (
          <List.Item
            title="Not Scored"
            subtitle={`${unscored}`}
            icon={{ source: Icon.Circle, tintColor: Color.SecondaryText }}
          />
        )}
      </List.Section>

      {criticalProjects.length > 0 && (
        <List.Section title="Critical Projects">
          {criticalProjects.map((p) => (
            <List.Item
              key={p.name}
              title={p.name}
              subtitle={`${p.score}/100`}
              icon={{ source: Icon.ExclamationMark, tintColor: Color.Red }}
            />
          ))}
        </List.Section>
      )}
    </List>
  );
}

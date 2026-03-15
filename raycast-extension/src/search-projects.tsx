import { ActionPanel, Action, List, Icon, Color, open } from "@raycast/api";
import { loadProjects, loadHealthScores, getHealthIcon, getHealthLabel } from "./data";

export default function SearchProjects() {
  const projects = loadProjects();
  const scores = loadHealthScores();

  // Sort: pinned first, then by name
  const sorted = [...projects].sort((a, b) => {
    if (a.isPinned !== b.isPinned) return a.isPinned ? -1 : 1;
    return a.name.localeCompare(b.name);
  });

  return (
    <List searchBarPlaceholder="Search projects...">
      {sorted.map((project) => {
        const health = scores[project.path]?.details;
        const score = health?.totalScore;
        const icon = getHealthIcon(score);
        const subtitle = [
          score !== undefined ? `${score}/100` : undefined,
          ...project.tags.slice(0, 2),
        ]
          .filter(Boolean)
          .join(" · ");

        return (
          <List.Item
            key={project.path}
            title={project.name}
            subtitle={subtitle}
            icon={project.isPinned ? { source: Icon.Star, tintColor: Color.Yellow } : Icon.Folder}
            accessories={[
              { text: icon },
              ...(project.tags.length > 0
                ? [{ tag: { value: project.tags[0], color: Color.Blue } }]
                : []),
            ]}
            actions={
              <ActionPanel>
                <ActionPanel.Section title="Open">
                  <Action.Open
                    title="Open in VS Code"
                    target={project.path}
                    application="Visual Studio Code"
                    icon={Icon.Code}
                  />
                  <Action.Open
                    title="Open in Terminal"
                    target={project.path}
                    application="Terminal"
                    icon={Icon.Terminal}
                  />
                  <Action.ShowInFinder path={project.path} />
                </ActionPanel.Section>
                <ActionPanel.Section title="Copy">
                  <Action.CopyToClipboard
                    title="Copy Path"
                    content={project.path}
                    shortcut={{ modifiers: ["cmd", "shift"], key: "c" }}
                  />
                  <Action.CopyToClipboard
                    title="Copy Name"
                    content={project.name}
                  />
                </ActionPanel.Section>
                <ActionPanel.Section title="Info">
                  {score !== undefined && (
                    <Action
                      title={`Health: ${score}/100 (${getHealthLabel(score)})`}
                      icon={Icon.Heart}
                      onAction={() => {}}
                    />
                  )}
                  {project.notes && (
                    <Action
                      title={`Notes: ${project.notes}`}
                      icon={Icon.TextDocument}
                      onAction={() => {}}
                    />
                  )}
                </ActionPanel.Section>
              </ActionPanel>
            }
          />
        );
      })}
    </List>
  );
}

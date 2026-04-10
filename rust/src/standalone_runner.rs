use crate::health::calculate_health_score;

pub fn run_health_check(project_path: &str) {
    let health_score = calculate_health_score(project_path);
    println!("{:#?}", health_score);
}
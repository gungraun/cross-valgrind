mod target_matrix;

use crate::util::gha_output;
use clap::Subcommand;
use cross::shell::Verbosity;
use cross::CargoMetadata;
use cross::CommandExt;
use std::process::Command;

#[derive(Subcommand, Debug)]
pub enum CiJob {
    /// Return needed metadata for building images
    PrepareMeta {
        // tag, branch
        #[clap(long, env = "GITHUB_REF_TYPE")]
        ref_type: String,
        // main, v0.1.0
        #[clap(long, env = "GITHUB_REF_NAME")]
        ref_name: String,
        target: crate::ImageTarget,
    },
    /// Check workspace metadata.
    Check {
        /// tag, branch
        #[clap(long, env = "GITHUB_REF_TYPE")]
        ref_type: String,
        /// main, v0.1.0
        #[clap(long, env = "GITHUB_REF_NAME")]
        ref_name: String,
    },
    TargetMatrix(target_matrix::TargetMatrix),
}

pub fn ci(args: CiJob, metadata: CargoMetadata) -> cross::Result<()> {
    let cross_meta = metadata
        .get_package("cross")
        .expect("cross expected in workspace");

    match args {
        CiJob::PrepareMeta {
            ref_type,
            ref_name,
            target,
        } => {
            // Set labels
            let mut labels = vec![];

            let image_title = match target.name.as_ref() {
                "cross" => target.name.to_string(),
                // TODO: Mention platform?
                _ => format!("cross (for {})", target.name),
            };
            labels.push(format!("org.opencontainers.image.title={image_title}"));
            labels.push(format!(
                "org.opencontainers.image.licenses={}",
                cross_meta.license.as_deref().unwrap_or_default()
            ));
            labels.push(format!(
                "org.opencontainers.image.created={}",
                chrono::Utc::now().to_rfc3339_opts(chrono::SecondsFormat::Millis, true)
            ));

            gha_output("labels", &serde_json::to_string(&labels.join("\n"))?)?;

            let version = cross_meta.version.clone();

            // Set image name
            gha_output(
                "image",
                &crate::build_docker_image::determine_image_name(
                    &target,
                    cross::docker::CROSS_IMAGE,
                    &ref_type,
                    &ref_name,
                    false,
                    &version,
                )?[0],
            )?;

            if target.has_ci_image() {
                gha_output("has-image", "true")?
            }
            if target.is_standard_target_image() {
                gha_output("test-variant", "default")?
            } else {
                gha_output("test-variant", &target.name)?
            }
        }
        CiJob::Check { ref_type, ref_name } => {
            if ref_type == "tag" && is_latest_release_tag(&ref_name)? {
                gha_output("is-latest", "true")?
            }
        }
        CiJob::TargetMatrix(target_matrix) => {
            target_matrix.run()?;
        }
    }
    Ok(())
}

fn is_latest_release_tag(ref_name: &str) -> cross::Result<bool> {
    let Some(current) = crate::build_docker_image::parse_image_release_tag(ref_name) else {
        return Ok(false);
    };

    let tags = Command::new("git")
        .args(["tag", "--list", "v*"])
        .run_and_get_stdout(&mut Verbosity::Quiet.into())?;

    let latest = latest_release_tag(tags.lines());

    Ok(latest.is_some_and(|(tag, parsed)| parsed == current && tag == ref_name))
}

fn latest_release_tag<'a>(
    tags: impl Iterator<Item = &'a str>,
) -> Option<(&'a str, crate::build_docker_image::ImageReleaseTag)> {
    tags.filter_map(|tag| {
        crate::build_docker_image::parse_image_release_tag(tag).map(|parsed| (tag, parsed))
    })
    .max_by_key(|(_, parsed)| *parsed)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn chooses_latest_release_tag() {
        let latest = latest_release_tag(
            [
                "v3.27.0-alpha.2",
                "v3.27.0-beta.1",
                "v3.27.0-1",
                "v3.27.1-alpha.1",
            ]
            .into_iter(),
        );

        assert_eq!(latest.map(|(tag, _)| tag), Some("v3.27.1-alpha.1"));
    }
}

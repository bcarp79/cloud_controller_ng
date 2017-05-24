module VCAP::CloudController
  class DropletCreate
    def create_docker_droplet(build)
      droplet = droplet_from_build(build)
      droplet.update(
        docker_receipt_username: build.package.docker_username,
        docker_receipt_password: build.package.docker_password,
      )
      droplet.save

      Steno.logger('build_completed').info("droplet created: #{droplet.guid}")
      record_audit_event(droplet, build.package, UserAuditInfo.from_context(SecurityContext))
      droplet
    end

    def create_buildpack_droplet(build)
      droplet = droplet_from_build(build)

      DropletModel.db.transaction do
        droplet.save
        droplet.buildpack_lifecycle_data = build.buildpack_lifecycle_data
      end

      droplet.reload
      Steno.logger('build_completed').info("droplet created: #{droplet.guid}")
      record_audit_event(droplet, build.package, UserAuditInfo.from_context(SecurityContext))
      droplet
    end

    private

    def droplet_from_build(build)
      DropletModel.new(
        app_guid:             build.app.guid,
        package_guid:         build.package.guid,
        state:                DropletModel::STAGING_STATE,
        build:                build,
      )
    end

    def record_audit_event(droplet, package, user_audit_info)
      app = package.app
      Repositories::DropletEventRepository.record_create_by_staging(droplet,
                                                                    user_audit_info,
                                                                    app.name,
                                                                    app.space_guid,
                                                                    app.space.organization_guid
                                                                    )
    end
  end
end

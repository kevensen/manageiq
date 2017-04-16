module MiqAeMethodService
  class MiqAeServiceManageIQ_Providers_Openshift_ContainerManager < MiqAeServiceManageIQ_Providers_ContainerManager
    expose :container_image_registries, :association => true
    expose :create_project
    expose :delete_project
    expose :projects_from_provider
    expose :project_exists_in_provider?
    expose :users_from_provider
    expose :user_exists_in_provider?
    expose :add_user_in_provider
  end
end

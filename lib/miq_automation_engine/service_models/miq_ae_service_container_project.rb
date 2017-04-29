module MiqAeMethodService
  class MiqAeServiceContainerProject < MiqAeServiceModelBase
    expose :ext_management_system,  :association => true
    expose :container_groups,       :association => true
    expose :create_resource
    expose :add_role_to_user
  end
end

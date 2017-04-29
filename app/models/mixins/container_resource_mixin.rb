# ContainerResourceMixin provides capabilities to container
# resources.
module ContainerResourceMixin
  extend ActiveSupport::Concern
  require 'json'

  MIQ_CLASS_MAPPING = {
    "ContainerBuild"        => "BuildConfig",
    "ContainerBuildPod"     => "Build",
    "ContainerGroup"        => "Pod",
    "ContainerLimit"        => "LimitRange",
    "ContainerQuota"        => "ResourceQuota",
    "ContainerReplicator"   => "ReplicationController",
    "ContainerRoute"        => "Route",
    "PersistentVolumeClaim" => "PersistentVolumeClaim",
    "ContainerImage"        => "Image",
    "ContainerService"      => "Service",
  }.freeze

  # Retrieves the resource from the provider and returns the hash
  def get_from_provider(api_version = 'v1')
    method_name = "get_#{kind_in_provider.underscore}"
    response, error_code, msg = send_method(method_name, [name, namespace], api_version)
    if error_code == 404
      return nil
    elsif error_code != 200
      raise MiqException::MiqProvisionError, "Unexpected Exception while getting object with resource name #{name}, namespace #{namespace}, method name #{method_name}, HTTP response code #{error_code}, and message #{msg}."
    end
    response
  end

  # Retrieves the resource from the provider and returns the hash without unique
  # attributes (e.g. UID, self-link, resource version, etc.)
  def get_from_provider_clean(api_version = 'v1')
    response = get_from_provider(api_version)
    response[:metadata].delete(:selfLink)
    response[:metadata].delete(:uid)
    response[:metadata].delete(:resourceVersion)
    response[:metadata].delete(:creationTimestamp)
    response[:metadata].delete(:generation)
    response.delete(:status)
    response[:spec].delete(:clusterIP)
    response
  end

  # Updates the resource in provider.  This is a wholesale replace.  The
  # metadata/name and metadata/namespace are set to the name and namesapce of
  # this resource.
  def update_in_provider(resource, api_version = 'v1')
    method_name = "update_#{kind_in_provider.underscore}"
    resource.deep_symbolize_keys!
    resource[:metadata][:name] = name
    resource[:metadata][:namespace] = namespace
    if resource[:kind] != kind_in_provider
      raise MiqException::MiqProvisionError, "Unexpected Exception while updating object with resource name #{name} in namespace namespace #{namespace}.  The update kind #{resource[:kind]} doesn't match the existing resource kind #{kind_in_provider}."
    end

    params = [resource]
    response, error_code, msg = send_method(method_name, params, api_version)
    if error_code == 404
      return nil
    elsif error_code != 200
      raise MiqException::MiqProvisionError, "Unexpected Exception while updating object with resource name #{name}, namespace #{namespace}, method name #{method_name}, HTTP response code #{error_code}, and message #{msg}."
    end
    response
  end

  # Deletes the resource from the provider.  This is an HTTP delete, by the
  # client.
  def delete_from_provider(api_version = 'v1')
    method_name = "delete_#{kind_in_provider.underscore}"
    response, error_code, msg = send_method(method_name, [name, namespace], api_version)
    # If for some reason this object doesn't exist in the provder, we will simply return nil
    if error_code == 404
      return nil
    elsif error_code != 200
      raise MiqException::MiqProvisionError, "Unexpected Exception while getting object with resource name #{name}, method name #{method_name}, HTTP response code #{error_code}, and message #{msg}."
    end
    response
  end

  def kind_in_provider
    MIQ_CLASS_MAPPING[self.class.name]
  end

  # Provides the name of the enclosing namesapce
  def namespace
    container_project.name
  rescue NameError
    nil
  end

  private

  # The send_method method actually invokes the Kubeclient call. The connect_client
  # method obtains a client from the ext_management_system that is either configured
  # for the OpenShift of Kubernetes API so that saves a step.
  def send_method(method_name, params, api_version = 'v1')
    resp = {}
    error_code = 200
    msg = ''
    begin
      client = container_project.ext_management_system.connect_client(api_version, method_name)
      unless client.discovered
        client.discover
      end
      rest_resp = client.send(method_name.to_sym, *params)
      # If the response is a rest response, then we will break up the
      # information returned
      if rest_resp.kind_of?(RestClient::Response)
        error_code = rest_resp.code
        resp = JSON.parse(rest_resp.body)
        msg = rest_resp.description
      else
        resp = rest_resp.to_h
      end
    rescue KubeException => e
      error_code = e.error_code
      msg = e.message
    end
    return resp, error_code, msg
  end
end

# ContainerResourceParentMixin provides capabilities to container
# resources that provide hierarchical management to other container
# resources.
module ContainerResourceParentMixin
  extend ActiveSupport::Concern
  require 'json'
  def get_resource_by_name(resource_name, kind, namespace = name, api_version = 'v1')
    method_name = "get_#{kind.underscore}"
    response, error_code, msg = send_method(method_name, [resource_name, namespace], api_version)
    if error_code == 404
      return nil
    elsif error_code != 200
      raise MiqException::MiqProvisionError, "Unexpected Exception while getting object with resource name #{resource_name}, method name #{method_name}, HTTP response code #{error_code}, and message #{msg}."
    end
    response
  end

  def get_resources(kind, api_version = 'v1')
    resources = []
    method_name = "get_#{kind.underscore.pluralize}"
    response, error_code, msg = send_method(method_name, [:namespace => name], api_version)
    if error_code != 200
      raise MiqException::MiqProvisionError, "Unexpected Exception while getting objects with method name #{method_name}, HTTP response code #{error_code}, and message #{msg}."
    else
      response.each do |object|
        resources.push(object.to_h)
      end
    end
    resources
  end

  def patch_resource(obj)
    obj = obj.symbolize_keys
    obj[:metadata][:namespace] = name
    obj_name = obj[:metadata][:name]
    method_name = "patch_#{obj[:kind].underscore}"
    response, error_code, msg = send_method(method_name, [obj_name, obj, name], obj[:apiVersion])
    if error_code != 200
      raise MiqException::MiqProvisionError, "Unexpected Exception while patching object with method name #{method_name}, HTTP response code #{error_code}, and message #{msg}."
    end
    response
  end

  def create_resource(obj)
    obj = obj.symbolize_keys
    obj[:metadata][:namespace] = name
    method_name = "create_#{obj[:kind].underscore}"
    response, error_code, msg = send_method(method_name, [obj], obj[:apiVersion])
    if error_code != 200
      raise MiqException::MiqProvisionError, "Unexpected Exception while creating object with method name #{method_name}, HTTP response code #{error_code}, and message #{msg}."
    end
    response
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
      client = ext_management_system.connect_client(api_version, method_name)
      rest_resp = client.send(method_name.to_sym, *params)
      # If the return is an entity list, this was probably invoked by a get_(someresource) method.
      # Therefore, we just return the entity list and allow the calling method to handle the Response
      # as necessary.
      if rest_resp.kind_of?(Kubeclient::Common::EntityList)
        resp = rest_resp
      elsif rest_resp.kind_of?(RestClient::Response)
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

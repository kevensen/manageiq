describe ContainerResourceMixin do
  describe 'container_project' do
    before(:each) do
      allow(MiqServer).to receive(:my_zone).and_return("default")
      hostname = 'host.example.com'
      token = 'eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJtYW5hZ2VtZW50LWluZnJhIiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZWNyZXQubmFtZSI6Im1hbmFnZW1lbnQtYWRtaW4tdG9rZW4tMXpkZmciLCJrdWJlcm5ldGVzLmlvL3NlcnZpY2VhY2NvdW50L3NlcnZpY2UtYWNjb3VudC5uYW1lIjoibWFuYWdlbWVudC1hZG1pbiIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VydmljZS1hY2NvdW50LnVpZCI6ImMyNmM0NDlmLTIxZTEtMTFlNy1hYzM0LTAwMGMyOTRlMGNiZCIsInN1YiI6InN5c3RlbTpzZXJ2aWNlYWNjb3VudDptYW5hZ2VtZW50LWluZnJhOm1hbmFnZW1lbnQtYWRtaW4ifQ.YxnMXhItkkBl8724_JnOBD0Pc7hKJ7tVBWET0XdOInWFBi6sGcrzg3ei7uRoM4xZ_B2P8YkALdpNk6PCSMbpI6JKB-oNioicZxy-HHzt2VofH-9qxjlOgKLHQEng4kuU8sUx7_RUQRwW0AEvPDF-8O-xcDZ1cZA9C17pOXcV7W_2Eirs2usrOvtSmBqWJDjuSLrWNa79i1_rG3QfcLqujsqzjI95H211MTOd-JxZeipX6KuyW_jmwO6UJUy2ct3P8ywn6Y4jUvYyf3F22Lmjf4euv71rXfGq_ZApVvQGb5fV7Z5mkXDexSyWFxIlomaSGe94hsKBsIAJvupRBr08_g'

      @ems = FactoryGirl.create(
        :ems_openshift,
        :name                      => 'OpenShiftProvider',
        :connection_configurations => [{:endpoint       => {:role       => :default,
                                                            :hostname   => hostname,
                                                            :port       => "8443",
                                                            :verify_ssl => OpenSSL::SSL::VERIFY_NONE},
                                        :authentication => {:role     => :bearer,
                                                            :auth_key => token,
                                                            :userid   => "_"}},
                                       {:endpoint       => {:role     => :hawkular,
                                                            :hostname => hostname,
                                                            :port     => "443"},
                                        :authentication => {:role     => :hawkular,
                                                            :auth_key => token,
                                                            :userid   => "_"}}]
      )
      @test_project = FactoryGirl.create(:container_project, :name => 'testproject', :ext_management_system => @ems)

      @test_replicator = FactoryGirl.create(:container_replicator, :name => 'testreplicator', :container_project => @test_project)

      @test_service = FactoryGirl.create(:container_service, :name => 'mysql', :container_project => @test_project)

      @test_delete_service = FactoryGirl.create(:container_service, :name => 'mysql2', :container_project => @test_project)
    end

    it "returns kind known to provider" do
      expect(@test_replicator.kind_in_provider).to eq("ReplicationController")
      expect(@test_service.kind_in_provider).to eq("Service")
    end

    it "returns correct namespace" do
      expect(@test_replicator.namespace).to eq("testproject")
    end

    it "knows the name of the resource" do
      expect(@test_replicator.name).to eq("testreplicator")
    end

    it "gets the resource from the provider as a hash" do
      VCR.use_cassette("mixins/#{described_class.name.underscore}/get_resoruce",
                       :match_requests_on => [:path,]) do
        results = @test_service.get_from_provider
        expect(results.kind_of?(Hash)).to be_truthy
      end
    end

    it "gets correctly named resource from the provider" do
      VCR.use_cassette("mixins/#{described_class.name.underscore}/get_resoruce",
                       :match_requests_on => [:path,]) do
        result = @test_service.get_from_provider
        expect(result[:metadata][:name]).to eq("mysql")
      end
    end

    it "gets the resource from the correct namespace in the provider" do
      VCR.use_cassette("mixins/#{described_class.name.underscore}/get_resoruce",
                       :match_requests_on => [:path,]) do
        results = @test_service.get_from_provider
        expect(results[:metadata][:namespace]).to eq("testproject")
      end
    end

    it "deletes the specified resource" do
      VCR.use_cassette("mixins/#{described_class.name.underscore}/delete_resoruce",
                       :match_requests_on => [:path,]) do
        result = @test_delete_service.delete_from_provider
        expect(result.kind_of?(Hash)).to be_truthy
        result = @test_delete_service.get_from_provider
        expect(result).to be_nil
      end
    end

    it "patches the resource in the provider" do
      VCR.use_cassette("mixins/#{described_class.name.underscore}/patch_resoruce",
                       :match_requests_on => [:path,]) do
        #data_to_patch = {:metadata => {:annotations => {:key => 'value'}}}
        data_to_patch = Kubeclient::Resource.new
        data_to_patch[:metadata] = {}
        data_to_patch[:metadata][:annotations] = {}
        data_to_patch[:metadata][:annotations][:key] = "value"
        @test_service.patch_in_provider(data_to_patch.to_h)
      end
    end
  end
end

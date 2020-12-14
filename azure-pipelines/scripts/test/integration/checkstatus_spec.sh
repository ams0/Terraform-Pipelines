# https://github.com/shellspec/shellspec

Describe 'checkstatus.sh integration tests'
  Include checkstatus.sh
  Describe 'checkPullRequest'
    #Function Mocks

    # Specs
    Context 'State: Not Expired, Status is Aborted and PR is current'
      It 'should update status to started'
      When run checkPullRequest "09/1/2100 18:0"  "Aborted" "17" "17"
        The output should include '"Status":{"value":"Started"}'
      End
    End  

    Context 'State: Not Expired, Status is Completed and PR is not current'
    It 'should update status to started'
    When run checkPullRequest "09/1/2100 18:0" "Completed" "17" "23"
      The output should include '"Status":{"value":"Started"}'
    End
  End  

  Context 'State: Not Expired, Status is Started and PR is current'
    It 'should Skip update state and apply master'
    When run checkPullRequest "09/1/2100 18:0" "Started" "17" "17"
      The output should include 'Skip update State'
    End
  End  

  Context 'State: Not Expired, Status is Started and PR is not current'
    It 'should report a locked state"'
    When run checkPullRequest "09/1/2100 18:0" "Started" "17" "18"
      The output should include 'Locked by PullRequest: 17' 
      The status should be failure
    End
  End      

  Context 'State: Not Expired, Status is MasterApplied and PR is Current'
    It 'should skip master apply and go to feature branch'
    When run checkPullRequest "09/1/2100 18:08"  "MasterApplied" "17" "17"
      The output should include 'Skip update State'
      The status should be success
    End
  End   

  Context 'State: Not Expired, Status is MasterApplied and PR is not Current'
    It 'should show locked'
    When run checkPullRequest "09/1/2100 18:08"  "MasterApplied" "17" "18"
      The output should include 'Locked by PullRequest: 17'
      The status should be failure
    End
  End    

  Context 'State: Expired, Status is Completed and PR is current'
    It 'should update status to Started'
    When run checkPullRequest "09/1/2019 18:08"  "Completed" "17" "17"
      The output should include '"Status":{"value":"Started"}'
    End
  End

  Context 'State: Expired, Status is Completed and PR is not current'
    It 'should update status to Started'
    When run checkPullRequest "09/1/2019 18:08"  "Completed" "17" "21"
      The output should include '"Status":{"value":"Started"}'
    End
  End    

  Context 'State: Expired, Status is Aborted and PR is current'
    It 'should update status to Started'
    When run checkPullRequest "09/1/2019 18:08"  "Aborted" "17" "17"
      The output should include '"Status":{"value":"Started"}'
    End
  End    

  Context 'State: Expired, Status is Aborted and PR is not current'
    It 'should update status to Started'
    When run checkPullRequest "09/1/2019 18:08"  "Aborted" "17" "22"
      The output should include '"Status":{"value":"Started"}'
    End
  End    
  
  Context 'State: Expired, Status is MasterApplied and PR is current'
    It 'should update status to aborted'
    When run checkPullRequest "09/1/2019 18:08"  "MasterApplied" "17" "17"        
      The output should include '"Status":{"value":"Aborted"}}'
      The status should be failure
    End
  End   

  Context 'State: Expired, Status is MasterApplied and PR is not current'
    It 'should expired PR and fail'
    When run checkPullRequest "09/1/2019 18:08"  "MasterApplied" "17" "18"
      The output should include 'Pull Request: State expired:'
      The output should include 'Status":{"value":"Aborted"}}'
      The status should be failure
    End
  End  
  End
End
  
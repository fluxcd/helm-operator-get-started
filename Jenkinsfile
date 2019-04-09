import groovy.json.*
node {
        
    env.jobname = "${env.JOB_NAME}" 
    env.rut = "/var/lib/jenkins/jobs/${env.JOB_NAME}/workspace/hack/"    
        
    try {
        notifyBuild('STARTED')

            stage('Clone repository') {
                /* Let's make sure we have the repository cloned to our workspace */
                checkout scm
            }
            
            stage('Docker push') {
                sh '("${rut}"script.sh -b dev)'
            }
             
        } catch (e) {
            // If there was an exception thrown, the build failed
            currentBuild.result = "FAILED"
            throw e
          } finally {
            // Success or failure, always send notifications
            notifyBuild(currentBuild.result)
          }
    }
def notifyBuild(String buildStatus = 'STARTED') {
   // build status of null means successful
   buildStatus =  buildStatus ?: 'SUCCESSFUL'
 
   // Default values
   def colorName = 'RED'
   def colorCode = '#FF0000'
   def subject = "${buildStatus}: Job *${env.JOB_NAME}* [${env.BUILD_NUMBER}] ${env.Branch}"
   def summary = "${subject} (${env.BUILD_URL})"
   def details = """<p>STARTED: Job <b>${env.JOB_NAME} [${env.BUILD_NUMBER}] ${env.Branch}</b>:</p>
     <p>Check console output at "<a href="${env.BUILD_URL}">${env.JOB_NAME} [${env.BUILD_NUMBER}]</a>"</p>"""
 
   // Override default values based on build status
   if (buildStatus == 'STARTED') {
     color = 'YELLOW'
     colorCode = '#FFFF00'
   } else if (buildStatus == 'SUCCESSFUL') {
     color = 'GREEN'
     colorCode = '#00FF00'
   } else {
     color = 'RED'
     colorCode = '#FF0000'
   }
 
    // Send notifications
         slackSend (color: colorCode, message: summary)
 
}

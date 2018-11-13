
properties([
    parameters([
        string(name: "commit", description: "Commit to build", defaultValue: "")
    ])
])

node("docker") {

    stage("Checkout Project") {
        checkout scm
    }

    def image
    def tag

    stage("Build Docker Image") {
        def revision = params.commit ?: sh(returnStdout: true, script: "git ls-remote --heads https://github.com/BitcoinUnlimited/BitcoinUnlimited.git ${env.BRANCH_NAME} | cut -f 1").trim()
        tag = sh(returnStdout: true, script: "git ls-remote --tags https://github.com/BitcoinUnlimited/BitcoinUnlimited.git | grep \"${revision}\" | cut -f 2 | cut -d / -f 3").trim()

        currentBuild.displayName = tag ?: "${env.BRANCH_NAME}-${env.BUILD_NUMBER}-${revision.take(6)}"

        docker.withRegistry('https://docker.dragon.zone:10080', 'jenkins-nexus') {
            image = docker.build("baharclerode/bitcoin-unlimited:${env.BRANCH_NAME}-${env.BUILD_NUMBER}-${revision.take(6)}", "--build-arg revision=${revision} .")
        }
    }

    stage("Push Docker Image") {
        docker.withRegistry('https://docker.dragon.zone:10081', 'jenkins-nexus') {
            image.push()
            image.push(env.BRANCH_NAME)
            if (tag) {
                image.push(tag)
            }
        }
    }
}